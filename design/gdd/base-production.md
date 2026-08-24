# Base & Production

> **Status**: **Approved** — independent `/design-review` 2026-07-21 (5 agents): verdict NEEDS REVISION,
> all **6 blocking clusters fixed in-file same session**, user accepted the revisions to Approved (see
> review log). **No design/number change** — every fix was doc-honesty, cross-doc-reconciliation, or AC
> hygiene. Structure numbers (hp/cost/build_time) and the closeout-drag brake remain
> validated-but-unplaytested (spike-gated — validate in the vertical-slice combat/economy spike); the
> Defensive Structure is the first VS entity with counters ON. **Re-reviewed 2026-07-22** (narrow delta —
> the `economy_outpost_discount` hook removal from Research's retune): verdict NEEDS REVISION (scope S) →
> 1 blocking regression-guard AC + 3 recommended doc-honesty one-liners fixed in-file same session, user
> accepted to Approved. Still **no design/number change**. **`/review-all-gdds` (2026-07-22) flagged one
> blocking consistency gap** — this doc's Downstream table didn't list Research/Tech as a Hard dependent
> despite the Research Lab reusing this system's lifecycle wholesale (a one-directional dependency gap;
> research-tech.md already listed the reverse). Fixed same session: added the Downstream row + reworded
> the stale "Provisional/undesigned" tag on the separate (reverse-direction) Research dependency entry.
> **Author**: user + main session (systems-designer + economy-designer on structure formulas/economy; qa-lead on acceptance criteria)
> **Last Updated**: 2026-07-22 (re-review revision — added a regression-guard AC against the removed
> `economy_outpost_discount` hook reappearing; added a sequencing cross-reference note (build-cost is
> sequence-invariant, income timing via AP Economy is not); reworded the Research/Tech Provisional
> Dependency entry to state it has zero current numeric ties; added a one-line Player Fantasy note that
> the Economy Outpost's payoff math lives in AP Economy. Prior 2026-07-21: independent `/design-review`
> revision — 6 blocking clusters fixed: (1) stale "blocked-until-Combat" AC preamble corrected — Combat's
> structure-attacker path is already defined; (2) `MAX_OUTPOST_COUNT` "disabled" clarified as *not* a pure
> no-op re: the registry `ap_income` ceiling; (3) start-of-turn ordering given a canonical owner — added
> the numbered sequence to `game-state-turn-manager.md` Core Rule 3, cited from Rule 6; (4) closeout-drag
> advisory AC split into two falsifiable ACs with a fixed fixture; (5) "spy hook" → state-based win-signal
> AC, "byte-identical" → field-wise state-equality predicate (matching Combat); (6) closeout arithmetic now
> states the income-differential term + break-even/HQ-siege honesty corrections. Also folded in 3
> recommended items: Research Lab exclusion AC, design-rule-toggle smoke ACs, cancel-refund boundary-rate
> examples. Prior 2026-07-21: reconciled with Research #8 — added the **Research Lab** as a 5th,
> Research-owned structure reusing this system's generic build/destroy mechanics. **Later 2026-07-21
> (Research #8 design-review):** Economy Tech was retuned from a build-cost discount to an `ap_income`
> bonus, so the `economy_outpost_discount` (4→3) hook is **removed** — Economy Outpost cost is a flat 4
> with no research discount (Core Rule 2).)
> **PIVOT 2026-08-05 (AP↔Credits split).** Structure `build_cost` and unit `produce_cost` are now
> **Credit** costs (the banked economy currency), each **plus a small AP surcharge** — `BUILD_AP_COST`
> (2) / `PRODUCE_AP_COST` (1) — so building/producing still costs a slice of the tactical turn (both
> owned by AP & Credits Economy). The cancel refund is now in **Credits**; `completed_outpost_count` now
> feeds **`credit_income`**. Defensive Structure attack stays **AP-only** (it is a combat action, not
> logistics). See ap-economy.md. This supersedes the "single AP pool" framing in the prose below, which
> is retained with inline flags.
> **Implements Pillar**: ⚠ Pillar 1 ("One Economy, Every Choice") is revised by the pivot — structures/
> units are now paid in **Credits + an AP surcharge**, not a single pool (wording TBD — see ap-economy.md
> Open Questions); Pillar 2 (Tempo Is the Skill — the "boom" half of the tempo duel; owns the endgame
> closeout-drag answer)
> **Creative Director Review (CD-GDD-ALIGN)**: SKIPPED — Lean review mode (not a phase gate). Review pillar alignment manually or in the independent `/design-review`.
> **Priority / Layer**: Vertical Slice / Core (system #7)

> ## ★★ REVISION BANNER — structure roster rebuilt (2026-08-24)
>
> **Status: IN REVISION.** Three user decisions on 2026-08-24 reshape this document's core subject:
>
> 1. **The Economy Outpost is DELETED.** Income moves to research (`ap-economy.md`,
>    `research-tech.md`). The structure whose only job was generating Credits has no job.
> 2. **The Production Outpost becomes the BARRACKS** — it produces infantry *and* raises the
>    infantry cap, and a faction may build at most `max_barracks` of them.
> 3. **Production is split by unit class.** Barracks make infantry; a **Factory** makes ground
>    vehicles; an **Airfield** makes aircraft. Each has its own per-faction maximum.
>
> ### The new structure roster
>
> | Structure | Produces | Also does | Max per faction | `build_cost` | `build_time` | `upkeep` |
> |---|---|---|---:|---:|---:|---:|
> | **HQ** | the faction's basic unit | is the win condition | 1 (fixed) | — | — | **0** |
> | **Barracks** *(was Production Outpost)* | `INFANTRY` | ★ **+`cap_per_barracks` infantry cap** | `max_barracks` (3) | **600** | 2 | **100** |
> | **Factory** *(new)* | `GROUND_VEHICLE` | — | `max_factories` (2) | **1,000** | 3 | **200** |
> | **Airfield** *(new)* | `AIR` | — | `max_airfields` (1) | **1,200** | 3 | **200** |
> | **Research Lab** | — | ★ **the entire economy** | 1 | **800** | 2 | **200** |
> | **Defensive Structure** | — | fires on enemies | `max_defensive` (3) | **500** | 2 | **100** |
> | ~~**Economy Outpost**~~ | ~~—~~ | ~~+2 Credit income~~ | **DELETED** | ~~600~~ | ~~1~~ | ~~100~~ |
>
> *(Maximums shown are the Democratic Alliance baseline. Every one is a faction lever, D5.)*
>
> ### ★★ Why the per-faction maximums are the important part
>
> This is not tidiness. `production/vertical-slice/REPORT.md` returned **PIVOT** because the AI kept
> choosing `BUILD` over manoeuvring — economy actions outscored movement by **12–20×** and, with
> unbounded Credits, were always affordable. **The fix is to run out of things to build.**
>
> With every structure capped, an Alliance player's *complete* build-out is:
>
> ```
> 3 Barracks (1,800) + 2 Factory (2,000) + 1 Airfield (1,200) + 1 Lab (800) + 3 Defensive (1,500)
>   =  7,300 Credits · 10 structures · total upkeep 1,400 · then nothing left to build, ever.
> ```
>
> Against an income ceiling of **2,500**, that build-out leaves **1,100 Credits/turn** for an army —
> which will not sustain a full 10-infantry cap at a roster mean upkeep of ~200. ★ **Maxing every
> structure is deliberately not affordable.** The player must choose between infrastructure and army,
> which is a real decision, and it is the decision the game currently does not make anyone face.
>
> A realistic build (2 Barracks, 1 Factory, 1 Lab = 600 upkeep) leaves **1,900** for an army of ~9.
> That is the intended shape.
>
> ### What is superseded in this document
>
> - § **`economy_outpost_payback`** — obsolete; the structure is gone.
> - `completed_outpost_count` / `credit_income` coupling — obsolete; income is research-keyed.
> - Every Economy-Outpost row in the stat table, its ACs, and its edge cases.
> - **Production Outpost** references retarget to **Barracks**; its `production_cap` semantics are
>   unchanged, but it gains a `cap_bonus`.
> - ★ The HQ's roster stays as-is (it produces the faction's basic unit only), so the existing
>   "HQ makes Scout, outpost makes the rest" shape survives the rename.
>
> ### New rules owed
>
> **BP-NEW-1 — Producers are class-matched.** A structure declares `produces_classes`. Barracks
> `{INFANTRY}`, Factory `{GROUND_VEHICLE}`, Airfield `{AIR}`. A produce order for a class no
> producer covers is rejected — and a faction with no Airfield in its roster simply cannot field
> aircraft, which is a legitimate identity statement (`unit-classes.md` UC-9).
>
> **BP-NEW-2 — Structure maximums are hard and per-faction.** `can_build(structure)` requires
> `completed + under_construction < max_for(structure, faction)`. Rejected at the build call site
> with a reason naming the maximum. A cancelled or destroyed structure frees its slot immediately.
>
> **BP-NEW-3 — The Barracks grants cap only while COMPLETED and alive.** Consistent with
> `population-cap.md` PC-5/PC-6: destroying a Barracks lowers the enemy's infantry cap, and units
> above the new cap are not destroyed — the owner is production-locked until attrition resolves it.
>
> **BP-NEW-4 — ★ A vehicle cannot be produced without a slot for its crew.** Producing a
> `requires_pilot` unit requires an available infantry slot (`population-cap.md` PC-8, PCOQ-4), so
> armour competes with infantry for the same ceiling. Whether the crew is produced *with* the
> vehicle or separately is **PCOQ-4, unresolved.**
>
> ### New open questions
>
> | # | Question | Owner |
> |---|---|---|
> | BPOQ-NEW-1 | ★ **Does the deleted Economy Outpost leave an early-game hole?** Its old job was also *"something useful to spend early Credits on"*. Now the early build order is Barracks → Lab → army, which is fewer meaningful choices in the opening. Watch the first five turns in playtest specifically | game-designer |
> | ~~BPOQ-NEW-2~~ | ✅ **RESOLVED 2026-08-24 (user): reuse the Economy Outpost art for the Factory.** The seven shipped files (`struct_economy_outpost_{rush,boom,neutral}_{idle,destroyed}.png` + `_idle_glow.png`) are re-pointed rather than retired — **zero new generations**, and the silhouette reads as industrial either way. Owed: rename the runtime files and their `.import` sidecars to `struct_factory_*`, update the asset manifest and the entity inventory, and correct `design/assets/specs/` so the spec describes a vehicle factory rather than an income building | ✅ closed |
> | BPOQ-NEW-3 | **Are Factory and Airfield both needed at first?** Air carries a real Pillar-3 risk (`unit-classes.md` UCOQ-1) and needs a renderer spike. Recommend shipping the Factory first and holding the Airfield until air is proven to render legibly | producer |

## Overview

Base & Production is OVERCLOCK's economic and army-generating engine: the data-driven structures a
player builds — the **HQ** (the sole starting structure, the win-condition target, and a limited
producer that can build only one basic unit type), the **Economy Outpost** (boosts Credit income), the
**Production Outpost** (a second producer that both unlocks the rest of the unit roster and lets a
player build units away from the HQ corner), and the **Defensive Structure** (a stationary
turret/bunker that trades mobility for a discounted attack and the ability to counterattack) — plus
the unit-production and deploy-tile flow that puts new units on the board. Every structure is built,
and every unit produced, by spending **Credits** (the banked economy currency) plus a small AP surcharge
— there is no separate "base-building phase", but Credits *are* the parallel economic currency the
2026-08-05 pivot introduced (the pre-pivot "single shared AP pool" framing is superseded; see
ap-economy.md). The player engages with this system directly and
constantly: what to build, where to place it, when to produce a unit and which empty tile to deploy
it to are some of the most consequential per-turn decisions in the game, on par with a move or an
attack. The system exists because it is the "boom" half of OVERCLOCK's rush-vs-boom tempo duel —
without it, AP has nothing to compound into — and because it owns the answer to the endgame
closeout-drag problem the concept prototype surfaced: rather than capping structures outright, it
keeps building expensive in both **Credits** and build time (and taxes each build a little **AP** too),
and makes the Production Outpost a real investment, so a losing player cannot cheaply spin up a
cornered, unlimited unit factory to stall a decided game.

## Player Fantasy

Base & Production is the **"boom"** — the deep satisfaction of investment that compounds. Where combat
is the sharp payoff of a plan and movement is the felt weight of repositioning, base-building is the
slow, deliberate pleasure of *setting up a machine* and watching it pay you back. The core fantasy is
**turning a corner of the map into a war engine**: you spend Credits now — on an Economy Outpost that
won't earn back its cost for a few turns, on a Production Outpost that unlocks your heavy hitters — and you
feel your future turns get richer for it. This is Pillar 2 (*Tempo Is the Skill*) made concrete on the
economic axis: the boom player's whole game is the bet that compounding beats immediate pressure, and
this system is where that bet is placed. It carries a matching tension — every structure is a
**commitment under a build timer**, exposed and unfinished, worth nothing until it completes and
refunding nothing if it's destroyed first. That vulnerable window is the counterweight to the boom
fantasy: booming *feels* powerful precisely because it is a gamble that a rusher can punish. And when
you place a Production Outpost forward and start deploying units into the enemy's half, or plant a
Defensive Structure that makes a chokepoint genuinely yours, the feeling is **projecting force onto the
map** — the base stops being a back-corner bank and becomes a front line you built.

> The Economy Outpost's "richer future turns" payoff (above) is felt here but **computed entirely by AP
> & Credits Economy** (now as **Credit** income) — this document owns the upfront cost and the vulnerable
> build window, not the payback formula (see Formulas, `economy_outpost_payback`, and `ap-economy.md`).

> `creative-director` not consulted — Lean review mode (specialist consultation reserved for HIGH-risk
> sections). Review this framing manually before production.

## Detailed Design

### Core Rules

1. **A structure type is an immutable data template** with: display name, `hp` (max), `build_cost`
   (**Credits** — plus the flat `BUILD_AP_COST` AP surcharge charged on every build, owned by AP &
   Credits Economy), `build_time` (owner-turns under construction), `production_cap` (units this structure may
   produce per turn; 0 for non-producers), and `producible_types` (which unit types it can build). The
   **Defensive Structure** additionally has `attack`, `attack_range`, `defense`, `can_counterattack`
   (true), and a Base-&-Production-owned `DEFENSIVE_ATTACK_COST`. All values are external data
   (Section D / registry), tunable without code.

2. **The four Vertical-Slice structures** (a fifth, the **Research Lab**, is **owned by Research / Tech
   #8** but is built and destroyed through this system's generic structure mechanics — see Rule 2b):
   - **HQ** — one per player, **placed at match setup, never built or rebuilt during play**. The
     win-condition target. Produces **Scout only** (`producible_types = {Scout}`), `production_cap = 2`.
     Highest `hp` in the roster. Losing it ends the match.
   - **Economy Outpost** — built during play. The **only** structure counted by
     `completed_outpost_count` (feeds `credit_income`'s tiered bonus). Does not produce units, does not
     attack. `build_cost` is a flat **4 Credits** (+ `BUILD_AP_COST` 2 AP) — **no research discount**.
     *(Research's **Economy Tech** was retuned 2026-07-21 from a build-cost discount to an income bonus per
     completed Economy Outpost; it now flows through **Credit income**, not this structure's cost. This
     supersedes the earlier `economy_outpost_discount` hook — see the Research/Tech #8 design-review.)*
   - **Production Outpost** — built during play. Produces **Trooper / Heavy / Sniper**
     (`producible_types = {Trooper, Heavy, Sniper}`), `production_cap = 4`. A **required investment to
     access the non-Scout roster**. Does not boost income.
   - **Defensive Structure** — built during play. A **stationary attacker**: it never moves; on the
     owner's turn the owner may spend the discounted `DEFENSIVE_ATTACK_COST` to fire it (Rule 8).
     `can_counterattack = true`. Does not produce, does not boost income.

   **2b. The Research Lab (5th structure, Research-owned).** Research / Tech (#8) adds a **Research Lab**
   that is built, placed, cancelled, and destroyed through **exactly the generic structure mechanics
   this system defines** (Rules 3–6, 9, 10) — no new mechanics here. Base & Production owns the
   lifecycle; **Research owns the Lab's stat values and everything it does** (researching techs). Its
   stats appear in the Section D table for roster completeness (hp 12 / `build_cost` 8 Credits / `build_time`
   2), tagged as Research-owned. It does not produce units (`production_cap = 0`) and does not feed
   `completed_outpost_count`.

3. **Structures occupy exactly one tile** (Grid single-occupant invariant). Every structure — friendly
   or enemy, under-construction or completed — **blocks movement traversal** (Movement Rule 3: all
   structures are hard blockers) and **blocks DIRECT line of fire** and is a **targetable enemy** for
   Combat. A structure can only be placed on a non-Impassable, unoccupied tile.

4. **Building a structure** spends `build_cost` **Credits** via `credits_spend()` **and** `BUILD_AP_COST`
   AP via `ap_spend()` — a single **both-or-neither** commit (legal only if the player can afford both;
   AP & Credits Economy Rule 11) — then places the structure on the chosen tile in the
   **Under-Construction** state. It occupies the tile immediately (blocking and targetable at once) but
   **produces no income, cannot produce units, and cannot attack until Completed**. It completes after
   `build_time` of the owner's turns elapse (Rule 6).

5. **Placement rule.** A structure (except the setup-placed HQ) may be placed on any **empty, passable
   tile** that is **adjacent (`manhattan_distance == 1`) to a friendly unit or friendly structure**
   *and* **more than 2 tiles (`manhattan_distance > 2`) from every enemy structure**. Tying builds to
   friendly presence means *building forward requires pushing forward*; the enemy-structure standoff
   prevents planting a base on top of the enemy HQ. If no legal tile exists, building that structure is
   unavailable.

6. **Build completion is a start-of-turn effect, processed *before* Credit income is added.** At the
   owner's start-of-turn, each of their Under-Construction structures decrements its remaining build
   turns; any that reach 0 transition to **Completed** *first*, and only then is `credit_income` computed
   and added — so a just-completed Economy Outpost counts toward income that same turn. **The ordering is
   owned by Game State & Turn Manager's canonical start-of-turn sequence** (`game-state-turn-manager.md`
   Core Rule 3: step 3 *apply start-of-turn effects — incl. this build-timer advance* precedes step 4b
   *add Credit income*). This GDD does not define the order — it contributes the build-timer-advance
   effect at step 3 and relies on the Turn Manager sequence to place it ahead of the income add; AP &
   Credits Economy cites the same sequence for its income timing.

7. **Producing a unit.** A **Completed** producer spends the unit's `produce_cost` **Credits** (Unit-owned
   value) **and** `PRODUCE_AP_COST` AP — a **both-or-neither** commit (legal only if the player can afford
   both) — and creates the unit **instantly** (Unit System: units have no build time) on a
   **player-chosen empty, passable tile adjacent (`manhattan_distance == 1`) to the producer**. The unit
   must be in that producer's `producible_types`. A structure may produce at most `production_cap` units
   **per turn** (`units_produced_this_turn`, reset at the owner's start-of-turn). If no empty adjacent
   tile exists, production is blocked (no unit spawns onto an occupied/off-board/Impassable tile).

8. **Defensive Structure attack.** On the owner's turn, the owner may spend `DEFENSIVE_ATTACK_COST` AP
   (Base-&-Production-owned, *lower* than the unit `attack_cost`) to fire the structure through
   **Combat's DIRECT targeting profile** against a legal enemy within its `attack_range`. It is **once
   per turn** (`has_attacked`, reset at start-of-turn) and immobile (it has no move action). Because
   `can_counterattack = true`, when it is itself attacked and the attacker is a legal target under its
   own DIRECT range/profile, it fires a **free counter** (Combat Rule 7). Its damage uses Combat's
   formula with the structure's `attack` as the attacker term (structure attack is **not**
   research-buffed in the VS — see Open Questions).

9. **Structure damage and destruction.** Structures take damage through **Combat's damage formula**
   `max(MIN_DAMAGE, effective_attack − cover_reduction − defense)`. At `hp` 0 a structure is
   **Destroyed** and removed from Grid occupancy in the same resolution step; its tile empties at once.
   Destroying an **HQ** triggers the Turn Manager's win-check (`win_condition`). Structures never move
   and (except the Defensive Structure) never attack.

10. **Voluntary cancel.** On their turn, the owner may **cancel** their own Under-Construction
    structure, refunding `CANCEL_REFUND_RATE` (default 50%) of its `build_cost` in **Credits** (via
    `credits_credit()`); the structure is removed and its tile empties. The **AP surcharge** paid at build
    time is **not** refunded (the tempo is spent). **Completed** structures cannot be cancelled (only
    destroyed in combat). **Destruction in combat refunds nothing** (the boom punish, per AP & Credits
    Economy Rule 8).

11. **`completed_outpost_count(player)` — the Credit-income contract.** Returns the count of the player's
    **alive, owned, Completed Economy Outposts** — HQ excluded, Production Outposts and Defensive
    Structures excluded, Under-Construction excluded. This is the exact query `credit_income` consumes;
    sampled at the owner's start-of-turn (after Rule 6 completions).

12. **Closeout-drag brake (required mechanic — no board clutter).** A losing player cannot cheaply stall
    a decided game, because: (a) a cornered **HQ produces only Scouts** (fragile hp-3 bodies that don't
    hold a line) at `production_cap = 2`/turn; (b) real production requires a **Production Outpost** —
    expensive in `build_cost` (Credits) + `build_time`, **destroyable while building with no refund**, and
    itself capped at 4/turn; (c) every build and produce also costs an **AP surcharge**
    (`BUILD_AP_COST`/`PRODUCE_AP_COST`) that competes with defending, so even a hoarded **Credit** war
    chest can't be dumped into a wall of units in one turn — the AP surcharge rate-limits it. *(Pivot note
    2026-08-05: Credits are now a parallel economic currency, so the brake no longer rests on "one pool";
    it rests on the Production-Outpost gate + the per-action AP surcharge. Re-validate the drag scenarios
    in playtest under the new banking model — a large saved war chest is the new watch-item.)* No hard
    structure cap is used in the VS (a disabled tuning lever, Section G). Game State's optional
    `MAX_ROUNDS` + tiebreak is the backstop. *(Detailed drag scenarios in Edge Cases.)*

13. **Deterministic and headless.** Placement, build-timer advance, production, structure attack, and
    destruction are pure functions of game state and the chosen action — no RNG, stable order,
    computable on a `clone()` for AI look-ahead and headless tests.

### States and Transitions

**Structure lifecycle:**

| State | Meaning | Transitions to |
|-------|---------|----------------|
| Under-Construction | Occupies its tile (blocks + targetable); produces no income/effect; cannot produce or attack | **Completed** (build timer reaches 0 at owner start-of-turn); **Destroyed** (hp → 0); **Removed** (owner cancels → tile empties, partial refund) |
| Completed | Fully functional (income / production / attack per type) | **Destroyed** (hp → 0) |
| Destroyed | Removed from Grid occupancy this step | (terminal) |

**Per-turn structure flags** (reset by the owner's start-of-turn, alongside unit flag reset):
`units_produced_this_turn` (producers) and `has_attacked` (Defensive Structure). The HQ has no distinct
"produced" state — a produced unit *is* Active on creation (Unit System Rule 2), placed on its deploy
tile.

### Interactions with Other Systems

| System | Data in | Data out | Interface owner |
|--------|---------|----------|-----------------|
| Grid & Terrain | `is_passable`, `occupant_at`, `neighbors`, `manhattan_distance` for placement/deploy/adjacency; `place`/`remove` on build/destroy | occupancy updates | Grid (mutation + query API) |
| AP & Credits Economy | `credits_spend`/`credits_can_afford` for `build_cost`/`produce_cost` (Credits) + `ap_spend`/`ap_can_afford` for `BUILD_AP_COST`/`PRODUCE_AP_COST` (both-or-neither); `ap_spend` for `DEFENSIVE_ATTACK_COST` (AP, a combat action); provides `completed_outpost_count` | `completed_outpost_count(player)` → `credit_income` | Base & Production owns the count query + all these costs' *timing*; Economy owns the two pools, the income *amounts*, and the `*_AP_COST` surcharges |
| Unit System | `produce_cost`, `producible_types` per unit; creates unit instances | new Active unit on the deploy tile | Unit System owns unit templates/state; Base & Production owns *which structure* produces *what*, and the deploy-tile choice |
| Combat Resolution | structure `hp`/`defense`; Defensive Structure `attack`/`attack_range`/`can_counterattack`; damage formula, DIRECT targeting | destroyed structure; HQ-destroyed → win-check | Combat owns targeting/damage/counter rules; Base & Production owns structure stats + `DEFENSIVE_ATTACK_COST` |
| Game State & Turn Manager | build/produce/cancel/structure-attack applied via `apply_action`; runs the start-of-turn build-timer advance + win-check | updated entities/state | Turn Manager (mutation path, start-of-turn sequencing, win rule) |
| Research / Tech | (owns the attack buff for **units**; structure attack un-buffed in VS) | — | Research owns the unit bonus |
| Command & Action Interface / HUD | legal build tiles, legal deploy tiles, build-timer progress, `production_cap` remaining, structure hp | display + selection | those systems own presentation |

**Public interface:** `legal_build_tiles(player, structure_type) -> set<tile>` ·
`build(player, structure_type, tile) -> Result` · `legal_deploy_tiles(producer, unit_type) -> set<tile>` ·
`produce(producer, unit_type, tile) -> Result` · `cancel_build(structure) -> Result` ·
`completed_outpost_count(player) -> int`. *(Defensive Structure attacks go through Combat's `attack()`,
which must accept a structure as attacker — see Dependencies handoff.)*

## Formulas

Base & Production is a **data/state** system — its "formulas" are the structure stat templates, two
derived quantities (cancel refund, outpost payback), and the `completed_outpost_count` contract (Core
Rule 11). Structure *damage* is not computed here — Combat owns `damage_formula`; structures are just
defenders (and the Defensive Structure an attacker) that plug into it.

### Structure stat templates (the data table)

| Structure | `hp` | `build_cost` (Credits; + `BUILD_AP_COST` 2 AP) | `build_time` (owner-turns) | `production_cap` (units/turn) | `producible_types` | `attack` | `attack_range` | `defense` | `can_counterattack` |
|-----------|------|-------------------|----------------------------|-------------------------------|--------------------|----------|----------------|-----------|---------------------|
| **HQ** | 40 | — (placed at setup) | — | 2 | {Scout} | — | — | 2 | false |
| **Economy Outpost** | 8 | 4 | 1 | 0 | {} | — | — | 0 | false |
| **Production Outpost** | 14 | 9 | 2 | 4 | {Trooper, Heavy, Sniper} | — | — | 0 | false |
| **Defensive Structure** | 10 | 6 | 1 | 0 | {} | 4 | 2 | 1 | true |
| **Research Lab** *(owned by Research #8)* | 12 | 8 | 2 | 0 | {} | — | — | 0 | false |

All values are external data (`.tres`/config), tunable without code (Tuning Knobs, Section G).
Ranges/rationale live in Section G; the shots-to-kill audit that justifies HQ hp 40 is below. **The
Research Lab row is shown for roster completeness only — its values and behavior are owned by Research /
Tech (#8), not this system (see Core Rule 2b); Base & Production owns only the generic build/destroy
lifecycle it reuses.**

### Named constants (Base & Production-owned)

| Constant | Value | Unit | Description |
|----------|-------|------|-------------|
| `DEFENSIVE_ATTACK_COST` | 1 | AP/attack | AP to fire a Defensive Structure — deliberately **< unit `attack_cost` (2)**, its reward for immobility. **Stays AP-only** (a combat action, not logistics — no Credit cost). |
| `CANCEL_REFUND_RATE` | 0.5 | fraction | Share of `build_cost` refunded **in Credits** on voluntary cancel of an under-construction structure (the AP surcharge is not refunded) |
| `MAX_OUTPOST_COUNT` | 10 (**disabled** in VS) | count | Hard ceiling on total outposts if ever enabled — off by default; documented so Credit income has a nameable cap lever. **Not a pure no-op:** with the hard cap off, the only bound on `completed_outpost_count` is board-tile availability. The registry's `credit_income` output range (`[10, 32]`) spans the un-teched *practical board-tile ceiling* (~26 at ≈12 outposts) up through the **Economy-Tech-boosted** ceiling (~32 — Research's per-completed-outpost income bonus, capped by `ECONOMY_TECH_TIER_THRESHOLD` (6)); it reflects board-tile availability (and that capped research modifier), **not** this disabled lever — so a very large (24×24) board can still push `n` past that soft ceiling. That residual runaway is the same one AP & Credits Economy flags as an open question; `MAX_OUTPOST_COUNT` re-imposes a hard bound if playtest needs it. **Pivot note:** Credit banking now also lets a player *accumulate* a large spendable stock even at a capped income rate — see AP & Credits Economy's re-opened snowball question. |

### `cancel_refund(structure)` — Credits returned on voluntary cancel

`cancel_refund = floor(structure.build_cost × CANCEL_REFUND_RATE)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `build_cost` | — | int | 4–9 (VS) | The structure's **Credit** build cost |
| `CANCEL_REFUND_RATE` | — | float const | 0.5 | Refund fraction |
| `cancel_refund` | — | int | 2–4 (VS) | **Credits** credited back to the banked pool on cancel (the AP surcharge is not refunded) |

**Output range:** `floor` keeps the Credit refund integer and rounds toward the harsher
(owner-unfriendly) side, matching `credit_income`'s conservative-clamp convention. **Only applies to
voluntary cancel** — combat destruction refunds nothing (0).
**Worked examples (default rate 0.5):** Economy Outpost `floor(4 × 0.5) = 2`; Production Outpost
`floor(9 × 0.5) = 4`; Defensive Structure `floor(6 × 0.5) = 3`.
**Boundary rates (tunable range 0.3–0.6):** at `0.3` → Economy `floor(4×0.3)=1`, Production
`floor(9×0.3)=2`, Defensive `floor(6×0.3)=1`; at `0.6` → Economy `floor(4×0.6)=2`, Production
`floor(9×0.6)=5`, Defensive `floor(6×0.6)=3`. `floor` keeps every result a non-negative integer across
the whole range — no degenerate output at either boundary.

> **Implementation note (representation, non-behavioral — ADR-0017):** the architecture stores
> `CANCEL_REFUND_RATE` as a **fixed-point integer percent** `cancel_refund_pct` (default **50**, tunable
> range **30–60**) rather than a float, computing `refund = build_cost * cancel_refund_pct / 100` via
> integer division. This keeps the Credit-refund path integer-only (ADR-0003 bans floats in the economy
> path; same fixed-point discipline as Movement's `soft_move_penalty_x10`). It is numerically identical
> to `floor(build_cost × rate)` across the entire 0.3–0.6 range — every worked example above is
> unchanged. No design or value change.

### `economy_outpost_payback` — derived ROI (informational, not a runtime value)

`payback_turns_from_completion = build_cost / OUTPOST_BONUS_TIER1 = 4 / 2 = 2.0`

Total elapsed break-even from the turn Credits are committed =
`build_time + ceil(build_cost / OUTPOST_BONUS_TIER1)` = `1 + 2 = 3` turns. `OUTPOST_BONUS_TIER1` (=2
Credits/turn) is **owned by AP & Credits Economy** — this GDD only sets `build_cost`/`build_time`. For the
5th+ outpost (tier 2, +1/turn) payback stretches to `4/1 = 4` turns from completion — the intended
diminishing-returns wall on over-booming. **Worked example:** an Economy Outpost committed turn 3 (spend 4
Credits + 2 AP) completes turn 4, first income bonus at turn 5's reset (+2 Credits), cumulative +2 / +4 /
+6 by turns 5 / 6 / 7 — so the cumulative Credit bonus equals the 4 Credits spent at turn 6 (**break-even
at turn 6**) and is strictly ahead from **turn 7 on**. *(The 2 AP surcharge is a one-time tempo cost, not
part of the Credit ROI.)*

> **Sequencing note (added 2026-07-22 re-review):** `build_cost` is **sequence-invariant** — researching
> Economy Tech before or after building an outpost costs the identical flat 4 Credits either way, since
> the tech no longer touches this cost (the old `economy_outpost_discount` hook is removed). But **income
> timing is not invariant**: Economy Tech's benefit is a per-turn `credit_income` bonus
> (`ECONOMY_TECH_INCOME_BONUS` capped by `ECONOMY_TECH_TIER_THRESHOLD`), so a player who researches
> *before* an outpost completes captures more teched-turns of that bonus than one who researches after.
> This document does not own that math — see `ap-economy.md`'s Formulas section for the actual bonus
> and cap.

### Structure damage & the `defense` field (uses Combat's formula — no new math)

Structures are defenders in Combat's existing
`damage = max(MIN_DAMAGE, effective_attack − cover_reduction − defense)`. Structures populate the
**same defender-agnostic `defense` field** the formula already reads (HQ 2, Defensive Structure 1,
outposts 0) — no formula change. The Defensive Structure is also an *attacker*: its `attack` (4) is the
`effective_attack` term when it fires (not research-buffed in the VS — see Open Questions).
**Shots-to-kill audit** (`ceil(hp / max(1, atk − def))`, no cover, unresearched):

| Attacker (atk) | HQ (hp40/def2) | Econ Outpost (hp8/def0) | Prod Outpost (hp14/def0) | Def Structure (hp10/def1) |
|---|---|---|---|---|
| Scout (2) | 40 | 4 | 7 | 10 |
| Trooper (3) | 40 | 3 | 5 | 5 |
| Heavy (5) | 14 | 2 | 3 | 3 |
| Sniper (6) | 10 | 2 | 3 | 2 |

The HQ costs a Sniper 10 hits × 2 AP = **≥20 AP in attacks alone** to destroy (attacks are AP-only) — and
**materially more in practice**: a Sniper first needs a Production Outpost (9 Credits + 2 AP + 2 turns)
and its own `produce_cost` (5 Credits + 1 AP) before firing, and with **AP carryover capped at
`AP_CARRYOVER_CAP` (5)** those 20 attack-AP still must be spread across many turns (`FLAT_AP_PER_TURN`
10/turn) while also paying to march the Snipers into range. A turn-3 HQ rush is therefore impossible, yet
a sustained late-game siege still finishes it (attrition-decided, never unkillable). Nothing one-shots
(min 2 hits). The Production Outpost dies to 3 Heavy hits (6 AP) — cheaper in AP than its 9-Credit + 2-AP
build is in Credits, keeping "defend it or lose your roster" real. Vs a
`defense`-2 HQ, Scout and Trooper both floor to 1 damage/hit — intended (they can't meaningfully siege
an HQ). The `defense + COVER_DR < lowest effective_attack` stacking constraint Combat flags **cannot
apply to any structure**: Combat Rule 6 makes **structures cover-immune** (a structure defender never
gains `cover_reduction`, whatever tile it stands on), so an HQ's mitigation is exactly its `defense 2` —
it can never stack to 3-with-Cover and floor-lock low-attack attackers, on any tile, under any map
generator. This supersedes the earlier "keep structures off Cover" caveat: the trap is closed by rule,
not by a placement assumption.

## Edge Cases

**Building & placement:**
- **If the chosen build tile becomes occupied or otherwise illegal between selection and commit** (a
  unit moved onto it, an enemy structure was built nearby making it within-2): `build()` re-validates
  and is **rejected** — nothing spent from either pool (both-or-neither), no structure placed.
- **If no legal build tile exists for a structure** (no empty passable tile adjacent to a friendly
  unit/structure that is also >2 from every enemy structure): that structure is **unavailable to
  build** this turn — the option is not offered.
- **If a candidate tile is adjacent to a friendly unit/structure but ≤2 tiles from an enemy
  structure**: it is **excluded** from `legal_build_tiles` — you cannot plant a base on the enemy's
  doorstep.
- **If an enemy structure that was enforcing the >2 standoff is destroyed**: tiles formerly excluded by
  it become legal on the next `legal_build_tiles` query (checked live, not cached).
- **If the player cannot afford `build_cost` (Credits) *or* the `BUILD_AP_COST` surcharge (AP)**: the
  build is not offered and `build()` rejects it — nothing spent from either pool (both-or-neither; AP &
  Credits Economy's dual afford gates + `apply_action` atomicity).
- **If the friendly unit that made a tile legal moves away or dies after the structure is placed**: the
  structure **stays** — placement legality is checked only at build time; adjacency is not maintained
  afterward.

**Build completion & timing:**
- **If an Economy Outpost completes at the owner's start-of-turn**: it transitions to Completed
  **before** Credit income is added that same turn (Rule 6), so it counts toward `credit_income`
  immediately — income reflects it that turn, not a turn late.
- **If several structures complete on the same start-of-turn**: all advance and complete before the
  single Credit-income add; a batch of Economy Outposts finishing together all count that turn.
- **If an under-construction structure is destroyed in combat**: it is removed that resolution step, its
  tile empties, and **no Credits are refunded** — the whole `build_cost` (Credits) is lost, along with
  the AP surcharge already spent (the boom punish, AP & Credits Economy Rule 8).
- **If an under-construction structure is attacked but survives**: it stays Under-Construction with its
  build timer unaffected — damage does not delay completion (hp and build progress are independent).

**Production & deploy:**
- **If a producer has no empty passable tile adjacent (`manhattan==1`)**: production is **blocked** — no
  unit can spawn onto an occupied, off-board, or Impassable tile (the unit would have nowhere to stand).
- **If a producer has already produced `production_cap` units this turn** (HQ 2 / Production Outpost 4):
  further production from it is **rejected** this turn, even with Credits and AP to spare —
  `units_produced_this_turn` gates it. It resets next start-of-turn.
- **If the player requests a unit type not in the producer's `producible_types`** (e.g. a Heavy from the
  HQ, which makes only Scouts): **rejected** — the HQ can never build non-Scouts; only a Production
  Outpost unlocks Trooper/Heavy/Sniper.
- **If the chosen deploy tile is occupied/off-board/Impassable at commit**: `produce()` re-validates and
  **rejects** — no unit, nothing spent from either pool (both-or-neither).
- **If an under-construction producer is asked to produce**: **rejected** — production requires
  Completed status.
- **If the producer itself no longer exists or is no longer Completed at commit**: `produce()`
  re-validates the producer's own existence/Completed status at the same atomic commit point as the
  deploy-tile check (mirroring that re-validation) — if the producer was destroyed or dropped out of
  Completed status between preview and commit, **rejects**: no unit, nothing spent from either pool. *(Currently unreachable
  in the VS — no verb self-damages a structure, so a producer cannot change state mid-preview under the
  single-verb atomic action model — but documented to close the door before any future verb, e.g. a
  Faction ability or Alpha AoE, could create the race.)*

**Cancel & destruction:**
- **If the owner cancels an under-construction structure**: it is removed, its tile empties, and
  `floor(build_cost × CANCEL_REFUND_RATE)` **Credits** are credited back (Economy Outpost 2, Production
  Outpost 4, Defensive Structure 3); the **AP surcharge** paid at build time is **not** refunded.
- **If the owner tries to cancel a Completed structure**: **not allowed** — completed structures can
  only be removed by combat destruction (which refunds nothing).
- **If the HQ would be built or cancelled**: never possible — the HQ is placed at match setup, is never
  a build option, and cannot be cancelled.
- **If an HQ's hp reaches 0**: it is destroyed and the Turn Manager's win-check fires
  `GameOver(winner = opponent)` in the same step; no further actions are accepted.

**Defensive Structure:**
- **If a Defensive Structure has already fired this turn** (`has_attacked == true`): further attacks are
  rejected — it is once-per-turn like a unit.
- **If a Defensive Structure is attacked, survives, and the attacker is within its `attack_range` (2)
  along a legal DIRECT line**: it fires a **free counter** (`DEFENSIVE_ATTACK_COST` is not charged for
  counters; `can_counterattack = true`).
- **If a Defensive Structure is attacked from outside its range** (e.g. a Sniper at range 3, or any
  attacker with a friendly/Impassable blocker on the line): **no counter** — the range/line gate makes
  out-ranging it a real tactic (kiting a turret with a Sniper works).
- **If a Defensive Structure's counter kills the attacker**: the attacker is removed that step; **no
  counter-to-the-counter** (Combat's one-counter-per-action structural rule).
- **If a player tries to move a Defensive Structure**: never offered — it is permanently immobile (no
  move action exists for structures).
- **If a Defensive Structure (or any structure) stands on a Cover tile**: Cover has **no effect** —
  **structures are cover-immune** (Combat Rule 6). As a defender the structure mitigates only through
  its own `defense` stat (Defensive Structure `defense 1`), never `defense + cover_reduction`; the min-1
  floor still applies. Structures may still legally *occupy* Cover tiles (placement is unchanged); Cover
  simply confers no damage reduction on them.

**Closeout-drag scenarios (the required treatment):**
- **If a losing player's Production Outpost is destroyed**: they fall back to **HQ Scout-only
  production, capped at 2/turn** — fragile hp-3 bodies that cannot hold a line. To regain real units
  they must rebuild a Production Outpost: **9 Credits + 2 AP surcharge + 2 build-turns exposed**, during
  which the winning player (who has board control) gets multiple free turns to finish the match or
  re-destroy the rebuild for as little as **6 AP in attacks** (re-destroy is a combat action — AP-only).
  **The exchange is even more lopsided than 6-vs-9 raw suggests, because of the income differential:** a
  winning player who is up on the board is almost always up on completed Economy Outposts too, so their 6
  attack-AP re-destroy is a *marginal* spend from a larger tactical budget backed by a fuller **Credit**
  income (e.g. 18–22 Credits/turn), while the loser's 9-Credit rebuild is the *majority* of a smaller
  income (often ≈`BASE_INCOME` 10 Credits once their outposts are gone) and still eats 2 of their AP for
  the surcharge, leaving them nothing for defense that turn. The winner therefore affords both the
  re-destroy *and* continued pressure while the loser can afford only the rebuild — so the loser cannot
  out-rebuild the destruction, and a decided game closes out rather than dragging. *(Pivot note 2026-08-05:
  under the AP↔Credits split the re-destroy is priced in AP (a combat action) and the rebuild in Credits +
  a 2-AP surcharge — the two costs are no longer the same pool, so the "marginal-vs-majority" argument now
  compares the winner's spare AP/Credit income against the loser's depleted Credit income plus surcharge
  drag; Credit banking is the new watch-item — see AP & Credits Economy's re-opened snowball question — but
  the surcharge still rate-limits how fast even a banked war chest converts to a rebuilt outpost.)* *(Caveat — spike-gated:
  this ignores the winner's **AP-to-reach** cost on the board. The closeout brake was originally validated
  map-agnostically, and the board was later pinned to 14×16 for a separate reason (rush/boom bimodality,
  AP & Credits Economy) — the two were never jointly re-checked. Validate the re-destroy-vs-rebuild exchange holds
  against the **VS-pinned 14×16 geometry** (corner-to-corner Manhattan distance 28) in the closeout
  playtest, per Open Questions. 8–24 remains the engine range for future map variety; a 24×24 stress case
  may still be worth running as an explicit future-map check, but it is not the VS validation target.)*
- **If a losing player Scout-spams from a safe HQ**: they cannot be *stopped* from producing (the HQ is
  never capturable in the VS), so they may delay **turn count** — but not the **outcome** (Scouts can't
  crack a winning army). Game State's optional `MAX_ROUNDS` + tiebreak is the backstop that bounds turn
  count if a slow winner won't close. *(This is the acceptable residual — the mandate was to stop
  decided games *dragging* into un-closeable, not to forbid a doomed player from acting.)*
- **If a player builds multiple Production Outposts to hedge against the brake**: legal and intended as a
  *winning*-player play (redundant production), but it could blunt the closeout brake if a *losing*
  player affords it. The response lever is the **disabled `MAX_OUTPOST_COUNT`** (Section G) —
  specifically a tighter Production-Outpost sub-cap — not raising `build_cost` further. Flagged as an
  Open Question to watch in playtest.

## Dependencies

**Upstream (this system depends on):**

| System | Nature | Interface |
|--------|--------|-----------|
| Grid & Terrain | Hard | `is_passable`, `occupant_at`, `neighbors`, `manhattan_distance` for placement/deploy/adjacency; `place`/`remove` on build & destroy; single-occupant invariant |
| AP & Credits Economy | Hard | `credits_can_afford`/`credits_spend` for `build_cost`, `produce_cost` (Credits) + `ap_can_afford`/`ap_spend` for `BUILD_AP_COST`/`PRODUCE_AP_COST` (both-or-neither); `ap_can_afford`/`ap_spend` for `DEFENSIVE_ATTACK_COST` (AP, a combat action); the cancel refund credits the **Credit** pool |
| Unit System | Hard | `produce_cost` per unit type; created unit instances placed on the deploy tile (units are instant) |
| Game State & Turn Manager | Hard | All actions applied via `apply_action`; the start-of-turn build-timer advance is sequenced ahead of the AP income snapshot; win-check on HQ destruction; clonable state for AI/tests |
| Combat Resolution | Hard | The Defensive Structure fires through Combat's `attack()` / DIRECT profile; all structures take damage via Combat's `damage_formula` and are destroyed by it |

**Downstream (systems that depend on this — all HARD):**

| System | What it needs from Base & Production |
|--------|--------------------------------------|
| AP & Credits Economy | `completed_outpost_count(player)` — the completed-Economy-Outpost count that feeds `credit_income` *(reciprocal: AP & Credits Economy is also upstream for `credits_spend`/`ap_spend`)* |
| Combat Resolution | Structure entities as targets: `hp`, `defense`, and the Defensive Structure's `attack`/`attack_range`/`can_counterattack` *(reciprocal: Combat is also upstream for damage/attack resolution)* |
| Research / Tech (#8, Approved) | The **Research Lab's entire structure lifecycle** — build/place/cancel/destroy, Under-Construction/Completed states, `build_cost`/`build_time`/no-refund-on-destruction — reuses this system's generic structure mechanics wholesale (Core Rule 2b). Research owns only the Lab's own stat values and tech data, not the lifecycle. *(Added 2026-07-22, `/review-all-gdds` — this dependency existed since the Research Lab landed 2026-07-21 but was missing from this table, a one-directional gap: research-tech.md already listed Base & Production as a Hard upstream dependency.)* |
| Command & Action Interface (#9) | `legal_build_tiles`, `legal_deploy_tiles`, build-timer progress, remaining `production_cap`, affordability |
| Game HUD (#10) | Structure hp, build progress, income contribution |
| AI Opponent (#11) | Build/produce/cancel actions and their legal-tile/affordability queries for planning |
| Faction Identity (#12) | May differentiate structure costs, `production_cap`, `producible_types`, or income per faction |

*(Bidirectional note: Grid, Unit System, AP & Credits Economy, Game State, and Combat each already list
Base & Production as a Hard dependent in their own GDDs — the graph is reciprocal.)*

**Provisional (hypothetical future dependency — the *reverse* direction: would Base & Production ever
depend on Research):**
- **Research / Tech (#8)** — Base & Production has **zero live numeric ties reading from Research**
  (updated 2026-07-22: the former `economy_outpost_discount` hook, its only numeric touch-point, is
  removed — Economy Tech's benefit now flows entirely through AP & Credits Economy's `credit_income`, not
  through anything Base & Production owns). The only remaining link is hypothetical: **should structure `attack`
  be research-buffed?** — currently OFF, an Open Question, not a current dependency. *(This is separate
  from — and does not replace — Research's Hard dependency ON Base & Production for the Research Lab's
  lifecycle, now listed in the Downstream table above.)*

**Cross-system handoffs owed (from this GDD):**
1. **→ Combat Resolution (#6, Approved) — LANDED 2026-07-21:** Combat's `attack()` accepts a
   **structure** as attacker (the Defensive Structure supplies `attack`/`attack_range`/`can_counterattack`).
   Combat's damage formula reads a defender-agnostic `defense`; this GDD populates it on structures
   (HQ 2, Defensive Structure 1), and Combat's `defense` note now reads "Unit- **and structure**-owned."
   Reconciled directly in `combat-resolution.md` (structure-as-attacker ACs + cover-immunity Rule 6).
2. **→ AP & Credits Economy (#3, Approved):** this GDD resolves the Economy's open "`completed_outpost_count`
   contract precision" question — the count is **completed, alive, owned Economy Outposts only**
   (Production/Defensive/HQ excluded, under-construction excluded).
3. **→ Unit System (#4, Approved):** `producible_types` (which structure builds which unit) is a **Base &
   Production-owned** structure property, not a unit stat — no Unit schema change; noted for awareness.
4. **→ Game State & Turn Manager (#2, Designed) — LANDED 2026-07-21:** the canonical start-of-turn
   ordered sequence (flags → start-of-turn effects/build-timer advance → Credit income snapshot) was added
   to `game-state-turn-manager.md` Core Rule 3 so build completions precede the income snapshot. Both this
   GDD (Rule 6) and AP & Credits Economy now reference that single sequence rather than each assuming the
   other enforces order.
5. **→ AP & Credits Economy (#3, Approved) — OWED:** the Economy's start-of-turn income-snapshot rule
   should add a one-line cross-reference to the Turn Manager canonical sequence (Core Rule 3, step 4) so
   its snapshot timing cites the shared order. Additive doc note only — no formula/value change. Apply on
   AP & Credits Economy's next revision (or via `/propagate-design-change`).

## Tuning Knobs

| Knob | VS Range | Default | Affects | If too high | If too low |
|------|----------|---------|---------|-------------|------------|
| `HQ_HP` | 30–50 | 40 | Rush resistance vs. endgame length | HQ near-unkillable → games drag | Turn-3 HQ rush becomes viable |
| `HQ_DEFENSE` | 1–3 | 2 | Flat mitigation on the HQ (structures are cover-immune, so this is the HQ's *entire* mitigation on any tile) | High values floor-lock low-atk units to 1 dmg/hit (still killable via the min-1 floor) | 0 → Scouts/Troopers chip the HQ efficiently |
| `HQ_PRODUCTION_CAP` | 1–3 | 2 | Scouts/turn a cornered HQ can pump | Higher → HQ Scout-spam can stall (weakens closeout brake) | 1 → HQ barely produces; forces early Production Outpost |
| `ECON_OUTPOST_HP` | 6–12 | 8 | How punishable an undefended boom is | Outposts hard to raid → booming too safe | 1-shottable → booming too fragile |
| `ECON_OUTPOST_BUILD_COST` | 3–6 | 4 | Boom payback speed | >6 → payback >4 turns, boom loses to rush on small maps | <3 → payback <2 turns, boom dominates |
| `ECON_OUTPOST_BUILD_TIME` | 1–2 | 1 | Exposure window before income starts | 2 → payback stretches to ~5 turns, weakens boom | (1 is the floor — instant income removes the vulnerable-investment tension) |
| `PROD_OUTPOST_HP` | 10–18 | 14 | Survivability of the roster gate | Too tanky → hard to punish, closeout brake weakens | Too fragile → roster access too easily denied |
| `PROD_OUTPOST_BUILD_COST` | 7–11 | 9 | **Closeout-drag brake strength** | Comeback attempts priced out (unfair) | Cheap rebuild → losing player stalls |
| `PROD_OUTPOST_BUILD_TIME` | 1–3 | 2 | Rebuild-cycle exposure window | 3 → "permanently locked out of roster" feels unfair if sniped | 1 → weaker brake |
| `PROD_OUTPOST_PRODUCTION_CAP` | 2–6 | 4 | Units/turn from a Production Outpost | High → mass-production swamps the dual-cost tension (Credits + per-unit AP surcharge) | Low → forces multiple outposts |
| `DEF_STRUCT_HP` | 8–14 | 10 | Shield durability | Unbreakable wall → stalls tempo | Too fragile → no zone denial |
| `DEF_STRUCT_BUILD_COST` | 5–8 | 6 | Cost to protect an economic target | Shielding never worth it | Turrets everywhere → turtle meta |
| `DEF_STRUCT_ATTACK` | 3–5 | 4 | Per-AP counter-harass efficiency | Turret out-values units → static play dominates | Turret ignorable |
| `DEF_STRUCT_ATTACK_RANGE` | 1–3 | 2 | Turret reach (matches Trooper) | Long-range turret dominates spacing | Range-1 turret trivially kited |
| `DEF_STRUCT_DEFENSE` | 0–2 | 1 | Turret tankiness per AP | Floor-locks low-atk attackers | 0 → no durability edge over an outpost |
| `DEFENSIVE_ATTACK_COST` | fixed **< 2** | 1 | Turret AP-efficiency vs units | (must stay below unit `attack_cost` 2) | — |
| `CANCEL_REFUND_RATE` | 0.3–0.6 | 0.5 | Cost of a wrong build commitment | →1.0 makes "build then bail" a free scout | 0 → cancel never worth it (= no voluntary cancel) |
| `MAX_OUTPOST_COUNT` (**disabled**) | 8–14 | 10 (off) | Hard income/production ceiling if enabled | — | Enabling low → caps legitimate booming |

**Design-rule toggles (fixed for the VS, not scalar knobs):**

| Toggle | VS Value | Notes |
|--------|----------|-------|
| Hard structure cap | **OFF** | Closeout-drag is braked by cost/time/quality instead (Core Rule 12). `MAX_OUTPOST_COUNT` is the lever if playtest shows multiple Production Outposts defeat the brake — enable as a Production-Outpost sub-cap first. |
| Build placement rule | adjacent to friendly unit/structure **and** >2 from enemy structures | Ties expansion to board presence + prevents doorstep bases. Turning off adjacency = teleport-anywhere builds (rejected). |
| HQ producible set | {Scout} | Single-type HQ is the quality half of the closeout brake. Widening it weakens the brake and the pressure to build a Production Outpost. |
| Structure attack research-buff | **OFF** | Research buffs units only; structure `attack` is flat in the VS (Open Question). |
| Parallel construction | allowed (dual-cost-gated) | No per-turn build-order cap in the VS; flagged as an Open Question (could a windfall spawn many builds in one turn?). *(Pivot 2026-08-05: each build now also spends `BUILD_AP_COST` 2 AP, and AP carries over only to `AP_CARRYOVER_CAP` 5 — so the per-build AP surcharge, not a no-banking rule, is what caps how many builds fit in one turn; Credits themselves bank unbounded.)* |

> Structure stat values are **data-driven** (external `.tres`/config), tunable without code. Costs and
> `production_cap` interact with AP & Credits Economy's income tiers and the closeout-drag brake — retune the two
> together, and re-validate the boom-vs-rush balance at the **VS-pinned 14×16 board** whenever a build
> cost moves (8–24 remains the engine range for future map variety, but VS balance is validated at
> 14×16; the map-size bimodality AP & Credits Economy flagged).

## Visual/Audio Requirements

Structures are the **fixed neon landmarks** of the board — anchored to the **Neon Retro-Future**
identity (presentation owned by Command & Action Interface #9 / HUD #10; stated here as requirements):
- **Silhouette-first, per type (Anchor Principle 1):** HQ, Economy Outpost, Production Outpost, and
  Defensive Structure must be distinguishable by **shape alone** — HQ largest/most imposing (it's the
  win target), Economy Outpost reads "civilian/industrial," Production Outpost reads "factory,"
  Defensive Structure reads "weapon/turret." Grayscale test applies.
- **Faction = hue (Principle 2):** every structure wears its owner's faction hue; who owns a base is
  readable across the room.
- **Build-state legibility (required):** an **Under-Construction** structure must read unmistakably as
  unfinished and inert — e.g. a translucent/scaffold/wireframe treatment with a **visible build-progress
  indicator** (turns remaining), distinct from a Completed structure. The vulnerable-investment fantasy
  depends on the player *seeing* that a base isn't earning yet.
- **Completion flourish:** a brief neon "power-on" when a structure completes (and, for an Economy
  Outpost, a cue tied to the income bump).
- **Deploy flourish:** producing a unit plays the unit's spawn beat on the player-chosen deploy tile
  (Unit System's produce cue).
- **Defensive Structure firing:** reuses **Combat's** attack-bolt language (flat neon bolt along the
  cardinal line) so a turret shot reads identically to a unit's — with its **free counter** using
  Combat's reserved reversed-direction counter treatment.
- **Destruction:** a brief flat-neon burst in the structure's faction hue, then immediate removal
  (matches instant-removal). An **HQ** destruction should be the biggest, most final beat on the board —
  it ends the match.
- **Dark stage, neon actors (Principle 3):** structures pop against muted terrain; build-progress and
  cancel/refund markings stay in the muted-UI register, not faction neon.
- Audio: distinct build-start, build-complete, produce, structure-attack, and destruction cues; HQ
  destruction gets a decisive victory/defeat sting (owned by the audio pass).

> `art-director` not consulted — Lean review mode; Base & Production is not a mandatory-visual category.
> Review this framing manually before production.

> 📌 **Asset Spec** — Visual/audio requirements defined. After the art bible is approved, run
> `/asset-spec system:base-production` for the four structure silhouettes, build-state/under-construction
> treatments, completion/destruction VFX, and audio cues.

## UI Requirements

Base & Production feeds the **pre-commit action menu** heavily — building and producing are among the
most decision-rich actions in the game. Combat/Movement own the shared overlay language; Base &
Production owns the **data**:
- **Build menu:** the buildable structures with their `build_cost` (**Credits**), the `BUILD_AP_COST` AP
  surcharge, and `build_time`, affordability-gated on **both** pools (`credits_can_afford` **and**
  `ap_can_afford` → available vs. greyed; both-or-neither), per AP & Credits Economy's dual-afford rule.
- **Legal-build-tile overlay:** on choosing a structure, highlight `legal_build_tiles`
  (adjacent-to-friendly **and** >2 from enemy structures); the two exclusion reasons should read
  distinctly where practical (no friendly adjacency vs. too close to enemy).
- **Deploy-tile overlay:** on producing, highlight the empty passable tiles adjacent to the producer
  (`legal_deploy_tiles`); if none, the producer reads as "blocked — no deploy space."
- **Build-progress + production readouts:** turns-remaining on Under-Construction structures; remaining
  `production_cap` this turn on each producer.
- **Cancel affordance:** cancelling an Under-Construction structure must show the **Credit** refund
  (`floor(build_cost×0.5)`) — and that the AP surcharge is **not** refunded — **before** confirming;
  mirrors Movement/Combat's cancel affordance.
- **Defensive Structure attack** uses Combat's targeting overlay (legal targets, pre-commit damage
  preview), gated on `DEFENSIVE_ATTACK_COST` affordability.

Presentation and interaction are owned by GDDs #9 and #10; this system provides the queries and data.

> 📌 **UX Flag — Base & Production**: The build menu, legal-build/deploy overlays, and build-progress
> readouts are core to readability. In Phase 4 (Pre-Production), run `/ux-design` for the core action
> interface **before** writing epics; stories should cite `design/ux/[screen].md`, not this GDD.

## Acceptance Criteria

> Base & Production is a **mixed Logic/Integration** system. Its **BLOCKING** gate is the Pure-Logic
> suite (deterministic, injected Grid + AP/Credits fixtures, no file I/O) plus Integration ACs that need
> real dependencies. `MAX_OUTPOST_COUNT` ACs are **infrastructure-only** (the cap is disabled in the VS — no
> coverage required). **Sequencing note:** the Defensive-Structure-attack Integration AC depends on
> Combat's `attack()` accepting a structure as attacker — that dependency is **satisfied**:
> `combat-resolution.md` (2026-07-21) defines the structure-as-attacker path (its "Structure as
> attacker (Defensive Structure)" Pure-Logic ACs + `attack()` accepting a structure attacker), so this
> AC is testable now — cross-reference Combat's structure-attacker ACs rather than duplicating them.

**Pure Logic gate (BLOCKING — fake/injected Grid + AP/Credits):**

*Templates (Rules 1–2):*
- **GIVEN** each structure template, **THEN** its fields match the table exactly — HQ (hp 40, cap 2,
  `{Scout}`, def 2, `can_counterattack` false), Economy Outpost (hp 8, cost 4, time 1, cap 0),
  Production Outpost (hp 14, cost 9, time 2, cap 4, `{Trooper,Heavy,Sniper}`), Defensive Structure
  (hp 10, cost 6, time 1, atk 4, rng 2, def 1, `can_counterattack` true, `DEFENSIVE_ATTACK_COST` 1).
- **GIVEN** any template read twice, **THEN** identical (immutable — queries never mutate).

*Occupancy (Rule 3):*
- **GIVEN** an Under-Construction structure on tile T, **THEN** T reports movement-blocked **and** stops
  a DIRECT LoF walk **and** is a legal target.
- **GIVEN** an Impassable or occupied tile, **THEN** `build()` there is rejected / never in
  `legal_build_tiles`.

*Building (Rule 4):*
- **GIVEN** ≥ `build_cost` **Credits** and ≥ `BUILD_AP_COST` **AP** and a legal tile, **WHEN**
  `build(Economy Outpost, tile)`, **THEN** **Credits −4 and AP −2** (both-or-neither — both pools pay or
  neither does), structure placed Under-Construction, blocks/targets immediately.
- **GIVEN** ≥ `build_cost` Credits but **< `BUILD_AP_COST` AP** (or the reverse), **WHEN**
  `build(Economy Outpost, tile)`, **THEN** rejected — **neither** pool is charged (both-or-neither).
- **GIVEN** a fresh Under-Construction structure, **THEN** `completed_outpost_count`, production, and
  attack all treat it as inert (0 contribution).

*Placement (Rule 5):*
- **GIVEN** an empty passable tile at manhattan 1 from a friendly unit and manhattan 3 from the nearest
  enemy structure, **THEN** it is in `legal_build_tiles`.
- **GIVEN** manhattan 1 from a friendly **structure** (not unit) and >2 from all enemy structures,
  **THEN** legal (unit **or** structure satisfies adjacency).
- **GIVEN** a tile at manhattan **exactly 2** from an enemy structure, **THEN** excluded (`>2` required).
- **GIVEN** a tile >2 from all enemy structures but not adjacent to any friendly, **THEN** excluded.
- **GIVEN** no tile satisfies both conditions, **THEN** `legal_build_tiles` is empty (build unavailable).
- **GIVEN** the HQ during play, **THEN** it is never in `legal_build_tiles` (setup-placed, exempt).
- **GIVEN** a structure legally placed adjacent to a friendly unit that **later moves away**, **THEN** it
  remains in place — no post-placement re-validation.

*Completion advance (Rule 6, pure slice):*
- **GIVEN** an Under-Construction structure with 2 remaining build-turns, **WHEN** the advance step runs
  once, **THEN** it decrements to 1 and stays Under-Construction.
- **GIVEN** one with 1 remaining, **WHEN** advance runs, **THEN** it becomes Completed; the advance
  function reads no income state (ordering is the caller's responsibility — the observable ordering is
  an Integration AC).
- **GIVEN** two structures both reaching 0 in the same advance call, **THEN** both Complete in that one
  call (batch).

*Production (Rule 7):*
- **GIVEN** a Completed Production Outpost (`units_produced_this_turn` 0) with ≥ `produce_cost` **Credits**
  and ≥ `PRODUCE_AP_COST` **AP**, **WHEN** `produce(Trooper, empty adjacent tile)`, **THEN** **`produce_cost`
  Credits and `PRODUCE_AP_COST` (1) AP spent** (both-or-neither), Trooper created on the tile, counter →1.
- **GIVEN** ≥ `produce_cost` Credits but **< `PRODUCE_AP_COST` AP** (or the reverse), **WHEN** `produce()`,
  **THEN** rejected — **neither** pool is charged (both-or-neither).
- **GIVEN** the HQ, **WHEN** `produce(Heavy, …)`, **THEN** rejected (not in `producible_types`).
- **GIVEN** a producer at `production_cap`, **WHEN** another `produce()` with Credits **and** AP to spare,
  **THEN** rejected (cap gates independently of both pools).
- **GIVEN** no empty adjacent tile, **THEN** production blocked, nothing spent from either pool.
- **GIVEN** an Under-Construction producer, **THEN** `produce()` rejected.
- **GIVEN** a producer destroyed or no longer Completed between preview and commit, **WHEN** `produce()`
  commits, **THEN** rejected — no unit, nothing spent from either pool (mirrors the deploy-tile commit
  re-validation).
- **GIVEN** start-of-turn reset, **THEN** `units_produced_this_turn` → 0 for that owner's producers.

*Defensive Structure (Rule 8, pure slice — AP/flag/immobility only; targeting legality is Combat's):*
- **GIVEN** a Completed Defensive Structure (`has_attacked` false) with ≥1 AP firing at a fixture legal
  target in range, **THEN** exactly **1** AP spent (not 2) and `has_attacked` → true.
- **GIVEN** `has_attacked` true, **WHEN** it attacks again, **THEN** rejected, no AP spent.
- **GIVEN** start-of-turn reset, **THEN** `has_attacked` → false.
- **GIVEN** any Defensive Structure, **THEN** it has no legal move action ever (immobility is structural).

*Destruction & win-hook (Rule 9, pure slice):*
- **GIVEN** a structure's hp set to 0, **THEN** it → Destroyed and a Grid `remove` is invoked for its
  tile the same step.
- **GIVEN** an **HQ** reaching 0 hp, **THEN** the resolution raises an **observable HQ-destroyed
  win-signal** — an `hq_destroyed` outcome on the returned `Result` (pure slice), which a real Turn
  Manager turns into `match_status == GameOver` with `winner == opponent` (see the Integration gate); a
  **non-HQ** reaching 0 raises **no** win-signal. *(State/return-value assertion — no test-double "spy"
  or mock infrastructure required.)*

*Cancel (Rule 10):*
- **GIVEN** an Under-Construction Economy Outpost / Production Outpost / Defensive Structure, **WHEN**
  cancelled, **THEN** `floor(cost×0.5)` = **2 / 4 / 3** **Credits** credited, structure removed, tile
  empties, **and the `BUILD_AP_COST` AP surcharge is NOT refunded** (the tempo is spent).
- **GIVEN** a Completed structure, **WHEN** cancel attempted, **THEN** rejected (no refund, unchanged).
- **GIVEN** a structure destroyed in combat, **THEN** the refund function is never called (0 refunded).

*`completed_outpost_count` (Rule 11):*
- **GIVEN** {2 Completed Economy Outposts, 1 Under-Construction Economy Outpost, 1 Completed Production
  Outpost, 1 HQ}, all one player's, **THEN** the query returns exactly **2**.
- **GIVEN** an opponent-owned Completed Economy Outpost, **THEN** excluded for this player.
- **GIVEN** a Completed Economy Outpost destroyed this step, **THEN** excluded (alive-only). **GIVEN**
  none qualify, **THEN** 0 (not null).
- **GIVEN** a Completed **Research Lab** (Rule 2b, Research-owned) and a Completed **Defensive Structure**
  owned by the player, **THEN** both are excluded — only Economy Outposts count (the Lab is not an income
  structure, `production_cap 0`, and never feeds `completed_outpost_count`).

*Formulas & determinism (Rules 10, 13):*
- **GIVEN** `build_cost` 4 / 9 / 6, **THEN** `cancel_refund` = 2 / 4 / 3; **GIVEN** an odd fixture cost 5,
  **THEN** `floor(5×0.5)=2` (floor, not round).
- **GIVEN** a fixture `S` and two independent clones (`A = clone(S)`, `B = clone(S)`), **WHEN** the same
  action (build / produce / cancel / structure-attack) is applied to `A` and to `B`, **THEN** `A` and
  `B` are equal under the **defined field-wise state-equality predicate** — every affected structure's
  `state` (Under-Construction/Completed/Destroyed), remaining build-turns, `hp`, `units_produced_this_turn`,
  `has_attacked`, both players' **AP and Credit pools**, and the Grid occupancy map all match (no RNG,
  stable iteration order). *(State-equality is this field-wise comparison, not byte-level serialization — no hashing or
  serialization infrastructure is required or implied. Matches the determinism predicate in
  `combat-resolution.md`.)*
- **GIVEN** a fixture `S` and a clone `C = clone(S)`, **WHEN** an action is applied to `C`, **THEN** `C`
  reflects the action and **`S` is unchanged** under the same predicate (clone isolation — resolution
  never mutates the source, so AI look-ahead is side-effect-free).
- **GIVEN** the VS config, **THEN** `MAX_OUTPOST_COUNT` reads **disabled** — an 11th Economy Outpost is
  **not** rejected on count grounds (the only build gate is tile availability + the dual Credit/AP afford
  check). *This one assertion IS worth a smoke check* (it guards the "disabled" claim); no further
  count-behavior coverage is required while the lever is off.

*Design-rule toggles (Section G — Config/Data smoke checks, guard against regression):*
- **GIVEN** sufficient **Credits and AP** for two builds in one turn, **THEN** both `build()` calls
  succeed the same turn (parallel construction is allowed, dual-cost-gated — no per-turn build-order cap
  in the VS).
- **GIVEN** a Completed Defensive Structure whose owner has researched Attack Tech, **THEN** its `attack`
  used by Combat is **unmodified** (4, not 5) — structure attack is **not** research-buffed in the VS.
- **GIVEN** a player who has researched Economy Tech, **WHEN** they build an Economy Outpost, **THEN**
  `build_cost` is unmodified (flat **4 Credits**) — Economy Tech affects `credit_income` only, not
  `build_cost`; the removed `economy_outpost_discount` hook must not be reintroduced (added 2026-07-22
  re-review, guards the discount-removal that motivated this session's re-review).

**Integration gate (BLOCKING — real Grid + AP + Turn Manager + Unit + Combat):**
- **GIVEN** the real stack, **WHEN** a player builds an Economy Outpost with exactly `build_cost` Credits
  and `BUILD_AP_COST` AP, **THEN** `apply_action` atomically spends **both** (Credits + AP surcharge,
  both-or-neither) + places it Under-Construction; a build unaffordable in **either** pool leaves
  Credits/AP/Grid all unchanged.
- **GIVEN** an Economy Outpost's timer reaching 0 at the owner's real start-of-turn, **THEN** that same
  turn's `credit_income` reflects it (e.g. 2 completed → income X; a 3rd completes → income
  X + `OUTPOST_BONUS_TIER1` **this** turn, not next) — **the end-to-end proof of Rule 6 ordering**.
  **AND** two Economy Outposts completing the same start-of-turn both count that turn.
- **GIVEN** a real Production Outpost producing a Trooper, **THEN** the Trooper is a real Unit entity on
  the chosen tile, immediately Active and selectable that turn.
- **GIVEN** a real Defensive Structure firing via Combat's `attack()` (structure as attacker) at an enemy
  in range 2 on a real DIRECT line, **THEN** Combat's formula applies with the structure's `attack 4` as
  `effective_attack` and the target's hp drops accordingly. *(Dependency satisfied — exercises Combat's
  structure-as-attacker path defined in `combat-resolution.md`.)*
- **GIVEN** a real `can_counterattack` Defensive Structure attacked by a unit within its range/profile,
  **THEN** a free counter fires through Combat's real counter step.
- **GIVEN** a real HQ reduced to 0 hp, **THEN** the real win-check fires `GameOver(winner = opponent)` in
  the same action and subsequent actions are rejected.
- **GIVEN** a real Under-Construction structure destroyed before completion, **THEN** removed from the
  real Grid that step, **nothing refunded** (neither the Credits nor the AP surcharge — the boom punish).
- **GIVEN** an enforcing enemy structure destroyed mid-game, **THEN** a later `legal_build_tiles`
  re-check makes previously-excluded nearby tiles legal (live, not cached).

**Advisory (documented playtest — a *tuning* target, NOT a correctness gate; the closeout-drag brake,
Rule 12):** These two ACs are advisory: a failure signals the closeout numbers need retuning
(`PROD_OUTPOST_BUILD_COST`/`_TIME`, `CLOSEOUT_TARGET_TURNS`, `HQ_PRODUCTION_CAP`), not a code defect.
Each names a **fixed fixture** and a **reference play line** so two testers score the same setup
identically. Reference fixture **CF-1** (shared by both): **VS-pinned 14×16 map**; player A (winning) holds their HQ,
one Completed Production Outpost, two Completed Economy Outposts, and ≥2 non-Scout units within
`manhattan_distance ≤ 4` of B's HQ; player B (losing) holds **only** their HQ (all outposts already
destroyed), Scouts-only at `production_cap 2`, `credit_income` = `BASE_INCOME` (10 Credits) with 0 outpost
bonus; it is A's start-of-turn. "Reference play line" = each side follows the deterministic greedy tempo AI (the
AI Opponent baseline) at a fixed difficulty, logged turn-by-turn in the playtest record.

- **AC-CLOSEOUT-A (A can close):** **GIVEN** fixture CF-1, **WHEN** A follows the reference optimal-
  closeout line, **THEN** B's HQ `current_hp` reaches 0 on or before A's turn in round
  **`CLOSEOUT_TARGET_TURNS`** (proposed 8, tunable). *Pass = HQ destroyed by the threshold; fail = A
  still hasn't closed → retune brake/target.*
- **AC-CLOSEOUT-B (B cannot out-rebuild):** **GIVEN** fixture CF-1, **WHEN** B follows the reference
  optimal-rebuild line, **THEN** by the end of round `CLOSEOUT_TARGET_TURNS` B has **not** achieved
  *both* (i) a rebuilt Production Outpost in the **Completed** state **and** (ii) ≥1 non-Scout unit
  produced from it that is still alive. *Pass = B fails to reach both (i) and (ii); fail = B stabilizes
  → the brake is too weak, retune `PROD_OUTPOST_BUILD_COST`/`_TIME`.*

## Open Questions

| Question | Owner | Notes / target |
|----------|-------|----------------|
| Do **multiple Production Outposts** let a losing player defeat the closeout-drag brake? | game-designer / economy-designer | The response lever is the **disabled `MAX_OUTPOST_COUNT`** as a *Production-Outpost sub-cap*, not raising `build_cost`. Watch in playtest. |
| Does **parallel/simultaneous construction** need a per-turn build-order cap? | systems-designer | A windfall could start many builds at once. *(Pivot 2026-08-05: Credits now bank unbounded, so a large saved war chest CAN fund many builds — but each build's `BUILD_AP_COST` 2 AP surcharge, with AP carryover capped at `AP_CARRYOVER_CAP` 5, is what now rate-limits builds-per-turn instead of the old no-banking rule.)* Confirm against the build-queue implementation. |
| Should **structure `attack` be research-buffed**? | Research (#8) / Combat | Currently OFF (research buffs units only). Revisit when Research is designed — a turret that scales with tech may be desirable. |
| What is the right **`CLOSEOUT_TARGET_TURNS`** threshold (proposed 8)? | game-designer / qa-lead | Tune in the vertical-slice playtest; the closeout-drag AC is advisory until this is validated. |
| **Production Outpost cost (9) has no ROI anchor** — it's a power-unlock, priced by feel. | economy-designer / game-designer | Validate "does turn 3–4 feel like the right time to unlock the full roster?" in playtest. |
| **HQ Scout-spam can drag turn count** (not outcome) since the HQ is never capturable. | game-designer / Game State | Acceptable residual; `MAX_ROUNDS` + tiebreak is the backstop. Confirm the cap feels right, not arbitrary. |
| Should the **Defensive Structure counter be capped** or interact with cover differently? | Combat (#6) | It's the first VS entity with `can_counterattack = true` — validate its feel when the ranged/counter spike runs. |
| Re-validate **boom-vs-rush at the VS-pinned 14×16 board** whenever a structure cost moves (8–24 is the engine range for future map variety). | game-designer / level design | The map-size bimodality AP & Credits Economy flagged; structure costs are tuned against provisional prototype economics. |
