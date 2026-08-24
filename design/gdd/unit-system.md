# Unit System

> **Status**: **Approved** (re-reviewed 2026-07-21 — the Research #8 delta re-review; verdict NEEDS
> REVISION → 2 additive-AC blockers fixed in-file → accepted to Approved). The `effective_defense`
> formula + two-flag split (`owner_has_attack_tech` / `owner_has_defense_tech`) were confirmed design-
> and logic-clean by all 3 delta specialists; the fixes added a `base_defense == 0` default AC and a
> testable flag-independence AC (no formula/rule/balance change). **The range-2 firing behavior AND the
> ranged/kiting subsystem remain Provisional/Experimental** — gated on a combat spike before their
> numbers lock (unchanged, spike-gated). Prior: fully Approved twice on 2026-07-20 (14 blockers closed).
> ⚠ **PIVOT 2026-08-05:** the AP Economy split into two resources, **AP** (tactical) and **Credits**
> (banked economic). `produce_cost` is now **dual-cost**: it is spent in **Credits** (the value
> unchanged — Scout/Trooper/Heavy/Sniper 2/4/5/7) plus a small flat `PRODUCE_AP_COST` (1) **AP**
> surcharge, both-or-neither. Move/attack costs are **unchanged and AP-only**. This pass corrects the
> stale single-pool worked examples below and renames "AP Economy" → "**AP & Credits Economy**"
> throughout; no roster stat, move-cost, or attack-cost value changed.
> **Author**: user + main session
> **Last Updated**: 2026-08-05 (economy pivot — produce dual-cost; stale AP examples corrected)
> **Implements Pillar**: Pillar 3 (Readable Board — silhouette-first, roles read at a glance); Pillar 2 (Tempo Is the Skill — unit roles create tactical depth)
> **Priority / Layer**: Vertical Slice / Core (system #4)

## Overview

Unit System defines the game's mobile combat pieces: the **data-driven templates** (each unit
type's hp, attack, attack range, movement cost, and production cost) and the **runtime state** of
every unit on the board (owner, current hp, position, whether it has attacked this turn). The
Vertical Slice ships four types — **Scout** (cheap, fast, fragile, melee), **Trooper** (efficient
range-2 line unit), **Heavy** (expensive, slow, durable, range 2), and **Sniper** (fragile glass
cannon, range 3) — spanning a cost-power ladder crossed with a short-vs-long range axis. Units are
the player's expression of
the "army" axis of the AP & Credits Economy: every unit is a Credits investment (plus a small
`PRODUCE_AP_COST` AP surcharge to field it), and choosing *which* units to field — and when — is a
core tempo decision. Unit definitions are external data (not hardcoded), so
stats can be tuned without code changes, and each unit's runtime state lives in the render-decoupled
game state so the AI can simulate with it and the tests can run headless.

## Player Fantasy

The player commands units directly, so this is a system they *engage with*, not just infrastructure.
The fantasy is a **small, instantly-readable roster where every unit has an obvious role** — you
never have to memorize a spreadsheet to know what a piece does; its silhouette and its place on the
cost ladder tell you. You compose an army by *intent*: fast Scouts to harass and grab space, Heavies as an anvil,
Troopers as the reliable backbone, and Snipers to threaten from range and punish poor spacing. The
new range axis adds positional depth — sightlines, blocking, and kiting — on top of the cost ladder.
This still serves Pillar 3 (*Readable Board, Deep Decisions*) — the depth is in *how you use* a small
set of clear pieces, not in roster bloat. The satisfaction is the Advance Wars feeling: clean,
legible units whose interactions run deep.

> **Legibility target (aesthetic):** the roster's roles are meant to read at the level of *intent*
> ("the durable one," "the long-range one"), NOT decimal efficiency ratios. Where a role is
> justified below by per-AP math, that math is the designer's internal check — it must also have an
> intent-legible story a player feels without arithmetic. The MDA aesthetic targeted by the
> range/kiting axis is **Challenge** (spatial mastery), not Sensation.

## Detailed Rules

### Core Rules

1. **A unit type is an immutable data template** with: display name, silhouette id, `hp` (max),
   `attack` (base), `attack_range` (tiles), `move_cost` (AP per tile entered), `soft_move_cap`
   (tiles a unit may move *cumulatively this turn* before movement cost escalates — see Rule 6), and
   `produce_cost` (**Credits** to build — since the pivot, producing also draws a flat
   `PRODUCE_AP_COST` **AP** surcharge, owned by the AP & Credits Economy, not by this stat; see Rule 3
   and Edge Cases). It additionally carries four **combat-infrastructure fields** the
   Combat GDD (#6) introduced but that this system **owns**: `defense` (flat damage mitigation, int ≥ 0),
   `targeting_mode` (enum {DIRECT, AREA}), `min_range` (AREA dead-zone floor, int; `attack_range` is the
   maximum reach for both profiles), and `can_counterattack` (bool). All four ship **off/neutral by
   default** across the entire VS roster — see Rule 3a. The Vertical-Slice roster is Scout / Trooper /
   Heavy / Sniper (stat table below).
2. **A unit instance has runtime state**: a unique `entity_id` (the identity Grid's occupancy map
   `tile → entity id` and Turn Manager's `entity_at()` key on — see Rule 2a for its uniqueness
   scope), a `type` reference to its immutable template (which Scout/Trooper/Heavy/Sniper it is —
   the source of every stat lookup and its `hp` ceiling), `owner` (P1/P2), `current_hp`, `position`
   (grid tile), `has_attacked` (per-turn flag), and `tiles_moved_this_turn` (per-turn counter, int ≥
   0, backing the soft-cap in Rule 6). Instances are created by Base & Production (produced at the
   HQ) and are **instant** — a produced unit exists immediately, no build time (units are the
   *responsive* option; buildings/research have build time, units do not).

   **2a. Unit-owned pure operations (the operations; Turn Manager owns *when* they run).** So that
   its own Logic-gate ACs are pure and headless, Unit System exposes these pure per-instance
   methods, which Turn Manager (and the AI) merely *call*:
   - `can_attack(unit) -> bool` — returns `not has_attacked` (Combat's legality check reads it).
   - `reset_turn_flags(unit)` — sets `has_attacked = false` and `tiles_moved_this_turn = 0`. Turn
     Manager calls this per unit at the **owner's** start-of-turn.
   - `duplicate(unit) -> unit` — returns a deep, independent copy (for AI look-ahead). `owner`,
     `entity_id`, and `type` are copied by value/reference-identity; all mutable state
     (`current_hp`, `position`, `has_attacked`, `tiles_moved_this_turn`) is independent.
   - **`entity_id` uniqueness scope:** `entity_id` is unique **within a single game state**, not
     globally. A `duplicate()` produced for AI simulation intentionally retains the source's
     `entity_id` because it represents a *parallel, non-coexisting* state (a separate Grid), not a
     second unit on the same board. Generation strategy: a deterministic, injectable/resettable
     sequential counter (no random UUIDs — upholds the "no random seeds" test rule).
3. **Stat table (the cost-power ladder):**

   | Type | `hp` | `attack` | `attack_range` | `move_cost` (AP/tile) | `soft_move_cap` (tiles) | `produce_cost` (Credits) |
   |------|------|----------|----------------|-----------------------|-------------------------|---------------------------|
   | **Scout** | 3 | 2 | 1 | 1 | 4 | 2 |
   | **Trooper** | 6 | 3 | 2 | 2 | 3 | 4 |
   | **Heavy** | 10 | 5 | 2 | 3 | 2 | 7 |
   | **Sniper** | 3 | 6 | 3 | 2 | 3 | 5 |

   Every `produce_cost` above also draws a flat `PRODUCE_AP_COST` (1, owned by the AP & Credits
   Economy) from the buyer's AP budget, both-or-neither with the Credits spend — see Edge Cases for
   the worked example. The ratios in this section price the **Credits** cost only, since `PRODUCE_AP_COST` is
   identical across the whole roster and does not change the *relative* ladder shape.

   **Roster identities (honest, per-Credit-audited).** At `produce_cost` the value ratios are: Scout
   hp/Credit **1.50**, atk/Credit **1.00**, (hp+atk)/Credit **2.50**; Trooper 1.50 / 0.75 / 2.25; Heavy
   1.43 / 0.714 / 2.14; Sniper 0.60 / **1.20** / 1.80. Amortized attack per 2-AP attack-action: Scout
   1.0, Trooper 1.5, Heavy 2.5, Sniper **3.0**. Read those honestly:
   - **Scout** — the **raw value-per-Credit leader** at range 1: highest (hp+atk)/Credit and best
     atk/Credit of the two cheapest. Its role is *breadth* — many fragile bodies, map control, harass.
     It is deliberately the most Credit-efficient body; it pays for that with 3 hp and range 1.
   - **Trooper** — the **efficient range-2 body**: among the range-2 units it has the best hp/Credit
     (1.50 > Heavy's 1.43). It is *not* the most efficient unit in the roster (the Scout ties its
     hp/Credit and beats its atk/Credit), and that is intended — the Trooper's niche is "the reliable,
     efficient piece that also reaches 2 tiles," a capability the Scout does not have. Its
     legibility story is "the dependable mid unit," not a decimal edge.
   - **Heavy** — **concentrated durability + alpha on ONE body / ONE action.** Its per-Credit ratios
     are intentionally the *weakest* in the roster (worst atk/Credit at 0.714, strictly below Trooper
     at range 2). You are not buying efficiency — you are buying **concentration**: 10 hp that cannot
     be chipped one cheap body at a time, and a single 5-attack (amortized 2.5 dmg/attack-action, tied
     top before the Sniper) that lands as one blow through one action of the shared economy. Ratios
     that spread value across several cheap bodies do not price that concentration; the anvil does.
     **The Heavy does *not* hold the raw-attack crown** — the Sniper's 6 attack is the roster's
     highest single hit. (Heavy `produce_cost` is **7 Credits**: at the old 6 it out-valued the
     Trooper on *both* hp/Credit and atk/Credit at range 2, leaving the backbone with no efficient-
     range-2 niche. Cost 7 hands range-2 hp/Credit to the Trooper; the trade is that the Heavy now has
     *no* per-Credit niche and stands entirely on concentration — a deliberate, audited consequence.
     Whether cost-7 Heavy actually gets built is a slice-tuning open question below.)
   - **Sniper** — the **raw-attack leader** (6, highest single hit) at the **longest range** (3), on
     a glass chassis (hp 3). Best attack-per-Credit in the roster. **Unvalidated** — see Open
     Questions; its whole ranged/kiting profile was never in the prototype, and its lack of a clear
     counter on this ladder is a named spike hypothesis, not a settled balance point.

   *(Sniper stats — and the range-2 firing behavior of Trooper/Heavy — are starting proposals; the
   whole ranged-combat model is unvalidated. See Open Questions.)*

   **3a. Combat-infrastructure stat fields (uniform across the VS roster).** Beyond the cost-power
   ladder above, every unit type carries four fields the Combat GDD (#6) introduced and this system
   **owns**: `defense`, `targeting_mode`, `min_range`, `can_counterattack`. They are **uniform across
   all four VS unit types** — every unit ships `defense = 0`, `targeting_mode = DIRECT`, `min_range = 1`,
   `can_counterattack = false` — so they are stated here as roster-wide defaults rather than as columns
   on the table above. They are **live infrastructure, off by default**: Combat resolves them now (a
   `defense`-2 or `AREA`/`can_counterattack` unit would work immediately), but no VS unit uses a
   non-default value. `attack_range` (Rule 1 / the table) is the **maximum** reach for both targeting
   profiles; `min_range` is the AREA-only near edge (1 for the direct-fire roster — no dead zone).
   Defaults and semantics are Combat-authoritative — if this summary disagrees with the Combat GDD, the
   Combat GDD wins (mirroring Rule 5).

4. **Units occupy exactly one grid tile** (Grid's single-occupant invariant). They block *enemy*
   movement; *friendly* units may path through them but cannot stop on an occupied tile (Movement rule).
5. **Attacks target the first blocker along a cardinal line, within `attack_range`.** Unit System
   owns exactly one thing here: the per-unit **`attack_range`** stat (Scout 1 adjacent-only,
   Trooper/Heavy 2, Sniper 3). The **targeting rule itself** — choosing one of the 4 cardinal
   directions, blocking line of fire on any occupied tile (friendly or enemy) *and* Impassable
   terrain, resolving to the nearest occupant (no shoot-through), and the legality gate that the
   first blocker must be an **enemy** — is **owned by the Combat GDD (#6)** and is summarized here
   non-authoritatively, for context only. **Precedence: if this summary ever disagrees with the
   Combat GDD, the Combat GDD wins** (mirroring AP & Credits Economy's action-cost precedence clause).
   `attack_range` is the unit-owned parameter Combat's rule reads.
6. **Attack is once-per-unit-per-turn** (`has_attacked`, reset by `reset_turn_flags()` at the
   owner's start-of-turn — Rule 2a). **Movement is AP-gated with a per-unit soft cap.** A unit may
   move multiple times in a turn and may **move *and* attack** in the same turn — there is no hard
   per-unit action limit beyond the attack flag. However, movement past the soft cap is surcharged:

   - The soft cap counts **cumulative tiles moved this turn** (`tiles_moved_this_turn`), **not**
     per-move-action. Splitting a long move into several `move()` calls does not reset the count —
     otherwise a unit could dodge the surcharge by chunking, a 50% AP exploit.
   - The first `soft_move_cap` tiles (cumulative) each cost the base `move_cost`. **Every tile beyond
     the cap costs a single flat surcharge** of `ceil(move_cost × SOFT_MOVE_PENALTY)` AP. This is a
     **two-level step function, not a multi-tier curve** — there is exactly one surcharge rate, and
     it does not keep rising the further past the cap a unit goes. (`ceil` keeps every AP cost an
     integer — see Rule 6a.)

   **Purpose (honest):** this is a brake on **deep single-turn over-extension — long repositions and
   rushes** — not a per-step kiting tax. A 1–2 tile standoff-maintenance kite sits *under* every
   unit's cap and is **not** taxed by this mechanic; whether kiting itself needs a separate brake is
   a combat-spike question (Open Questions). What the soft cap guarantees is that a unit cannot cheaply
   cross the whole board in one turn — reach in bulk must be paid for. The player is never *blocked*
   from over-extending, only made to pay a rising total for it.

   *(The per-unit `soft_move_cap` threshold and the `tiles_moved_this_turn` counter are Unit-owned;
   `SOFT_MOVE_PENALTY` is a **Unit-owned global constant** — not per-type — mirroring `soft_move_cap`.
   The escalation formula that consumes them is owned by the **Movement GDD (#5)** and must be added
   there — see Dependencies and Open Questions.)*

   **6a. Integer-AP invariant.** All AP costs are integers (matching Movement's and the AP & Credits
   Economy's published invariant — Credits are likewise always integers). Because
   `SOFT_MOVE_PENALTY`'s tuning range (1.5–3.0) times an odd `move_cost` can be fractional (e.g. Scout
   1 × 1.5 = 1.5, Heavy 3 × 2.5 = 7.5), the per-tile surcharge is **`ceil(move_cost ×
   SOFT_MOVE_PENALTY)`** — rounded up per over-cap tile so the cost is always an integer and always ≥
   the base `move_cost`. Movement's formula and this doc must agree on `ceil`.
7. **A newly produced unit may act the turn it is produced** (no summoning sickness) — AP and Credits
   permitting (production itself already happened; a fresh unit's own move/attack are AP-only).
8. **A unit dies when `current_hp` reaches 0** (Combat resolves the damage); it is removed from the
   grid immediately, in the same resolution step.
9. **Effective attack and defense include research buffs (two independent tech flags).** Research /
   Tech (#8) ships **three flat, independent** techs; two of them buff units, via **two independent
   boolean flags** on the owner's state:
   - `effective_attack = base attack + (owner_has_attack_tech ? RESEARCH_ATK_BONUS : 0)`
   - `effective_defense = base defense + (owner_has_defense_tech ? DEFENSE_TECH_BONUS : 0)`
   The buff magnitudes (`RESEARCH_ATK_BONUS`, `DEFENSE_TECH_BONUS`, both +1) are **owned by Research**;
   the unit stores only its `base attack`/`base defense` and the effective values are computed live from
   the owner's tech flags (a unit produced after research already reflects the buffs). `base defense` is
   0 for all VS units (the field was introduced to the schema via Combat's #6 handoff). *(This
   generalizes the former single-flag rule — Research chose independent flat techs, not a tiered/stacking
   bonus, so two booleans suffice.)*

### States and Transitions

**Instance lifecycle:**

| State | Meaning | Transitions to |
|-------|---------|----------------|
| Produced | Created at HQ this turn — a **presentation-only transient**, not a distinct game-logic state (no field observes it; a unit *is* Active on creation, and may gate a one-frame spawn flourish only) | Active (immediately — same step) |
| Active | On the board, can move/attack (AP + flags permitting) | Destroyed (hp → 0) |
| Destroyed | Removed from grid | (terminal) |

**Per-turn flags:** `has_attacked` goes false → true on attacking; `tiles_moved_this_turn`
accumulates on each move. Both are reset by `reset_turn_flags()` at the owner's start-of-turn (Turn
Manager calls it). `current_hp` only decreases (no healing in the VS) and is bounded `0 ≤ current_hp ≤ hp`.

### Interactions with Other Systems

| System | Data in | Data out | Interface owner |
|--------|---------|----------|-----------------|
| Grid & Terrain | position / occupancy | unit's tile | Grid |
| Game State & Turn Manager | stores unit instances; **calls** `reset_turn_flags()` at start-of-turn and `duplicate()` for AI (Unit owns the operations, Rule 2a) | unit runtime state | Turn manager (storage + *when*) |
| AP & Credits Economy | `move_cost` + over-cap surcharge spent via `ap_spend()` (AP); `produce_cost` spent via `credits_spend()` (Credits) **plus** a flat `PRODUCE_AP_COST` surcharge spent via `ap_spend()` (AP), both-or-neither | — | **Unit System owns these cost values**; AP & Credits Economy owns both pools |
| Base & Production | creates instances at HQ | new unit on board | Base & Production (production) |
| Combat Resolution | reads `hp`/effective attack/`attack_range`/`can_attack()`; resolves the cardinal-line-first-blocker targeting; applies damage; sets `has_attacked` | destroyed flag | Combat owns `attack_cost` (2 AP), the line-of-fire/targeting rule, and the damage formula; Unit owns `attack_range` + `can_attack()` |
| Movement | reads `move_cost`, `soft_move_cap`, `tiles_moved_this_turn`, `SOFT_MOVE_PENALTY` | writes `tiles_moved_this_turn` | Movement owns pathing **and the soft-cap surcharge formula (new — must be added)**; Unit owns the values + counter field |
| Research / Tech | owner tech flag → +attack to all units | effective attack | Research owns the bonus magnitude |
| Command & Action Interface / HUD | type, hp, has-acted, blocked-shot reason | display + selection | those systems own presentation |

## Formulas

Unit System has essentially no *balance* formulas — its numbers are the stat table (Core Rule 3).
The one derived quantity it owns:

### `effective_attack(unit)`

`effective_attack(unit) = unit.base_attack + (owner_has_attack_tech ? RESEARCH_ATK_BONUS : 0)`

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `unit.base_attack` | int | 2–6 | Base attack from the stat table (Scout 2 / Trooper 3 / Heavy 5 / Sniper 6) |
| `owner_has_attack_tech` | bool | — | Whether the unit's owner has completed **Attack Tech** (one of Research's three techs) |
| `RESEARCH_ATK_BONUS` | int const, ≥0 | +1 | Attack added by Attack Tech — **owned by the Research GDD**, referenced here; a single non-negative flat int |
| `effective_attack` | int | 2–7 (at current bonus) | The attack value Combat uses |

**Output range:** 2 (un-researched Scout) to 7 (researched Sniper) *at the current `RESEARCH_ATK_BONUS = +1`*. **Example:** a researched Trooper
= 3 + 1 = 4; a researched Sniper = 6 + 1 = 7.

> **Research coupling (RESOLVED 2026-07-21):** `RESEARCH_ATK_BONUS` is owned by the Research GDD (#8);
> the +1 shown here is illustrative — **if Research's value disagrees, Research wins.** Research shipped
> **three flat, independent** techs (Attack / Defense / Economy), so this is a **single boolean flag**
> (`owner_has_attack_tech`) gating a single flat int — the exact shape this formula already assumed;
> **no tiered/stacking revision was needed.** Defense Tech is handled by the separate
> `effective_defense` formula below (a second independent flag), not by extending this one. The stated
> 2–7 range and any per-type researched values go stale if the bonus is ever ≠ +1 — so tests must read
> the bonus from Research's config, never hardcode the researched totals (see Acceptance Criteria).

### `effective_defense(unit)`

`effective_defense(unit) = unit.base_defense + (owner_has_defense_tech ? DEFENSE_TECH_BONUS : 0)`

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `unit.base_defense` | int | 0 (all VS units) | Base defense — the field Combat's `damage_formula` reads (introduced to the schema via Combat's #6 handoff; 0 for the whole VS roster) |
| `owner_has_defense_tech` | bool | — | Whether the unit's owner has completed **Defense Tech** (Research #8) |
| `DEFENSE_TECH_BONUS` | int const, ≥0 | +1 | Defense added by Defense Tech — **owned by the Research GDD**; provisional/playtest-gated |
| `effective_defense` | int | 0–1 (VS) | The `defense(defender)` term Combat's `damage_formula` consumes — **no Combat change** (the term was already generic) |

**Output range:** 0 (un-researched) to 1 (researched). **Example:** a researched player's Trooper has
`effective_defense = 0 + 1 = 1`; an enemy un-researched Scout then deals `max(1, 2 − 0 − 1) = 1`.

> **Mirror of `effective_attack`, introduced by Research (#8) 2026-07-21.** `DEFENSE_TECH_BONUS` (+1) is
> **provisional/playtest-gated**: with `COVER_DR = 1`, a researched unit on Cover reaches 2 mitigation,
> floor-locking low-attack enemies to `MIN_DAMAGE` 1 (a legibility risk — Combat's defense-stacking
> constraint). Tests must read the bonus from Research's config, not hardcode it.

> **Soft-cap surcharge (owned by Movement, stated here for context):** per over-cap tile the cost is
> `ceil(move_cost × SOFT_MOVE_PENALTY)`, applied to each tile past `soft_move_cap` cumulative this
> turn — a flat single-step surcharge. Worked example below in Edge Cases. Unit owns the inputs
> (`soft_move_cap`, `SOFT_MOVE_PENALTY`, `tiles_moved_this_turn`); Movement owns the summation.

> Damage dealt is **not** computed here — Combat owns the damage formula (attacker's
> `effective_attack` minus cover, min 1, plus counterattacks). Total movement AP cost is owned by
> Movement. This section defines only the unit-owned derived value.

## Edge Cases

- **If a unit's `current_hp` reaches 0**: it is destroyed and removed from the grid in the same
  resolution step; its tile becomes empty immediately.
- **If a unit has already attacked this turn**: further attack attempts are rejected (once-per-turn,
  `can_attack()` returns false); it **may still move** if AP allows (movement is not gated by
  `has_attacked`).
- **If no enemy is the first blocker within `attack_range` in any cardinal direction**: the unit has
  no legal attack this turn (it may still move). A friendly unit or Impassable tile between the
  attacker and an enemy **blocks the shot** — the enemy is not targetable through it. (The HUD must
  distinguish *blocked-by-friendly* from *out-of-range* / *blocked-by-enemy* so a blocked shot reads
  as a rule, not a bug — owned by the Command & Action Interface.)
- **If two enemies are in line** (e.g. a Sniper looking down a row at two stacked enemies): only the
  **nearest** (first blocker) can be targeted — there is no shoot-through or pierce in the VS.
- **If a Sniper (range 3) and a Heavy (range 2) face off at distance 3**: the Sniper can fire but the
  Heavy cannot until it closes one tile — the intended kiting dynamic. **Note:** the soft-cap
  surcharge does *not* tax this exchange (the Heavy closing 1 tile is well under its cap 2), so
  whether this standoff is oppressive is a pure ranged-balance question for the spike, not something
  the soft cap addresses. (Balance-sensitive; unvalidated.)
- **If a unit is produced this turn**: its `has_attacked` is false, `tiles_moved_this_turn` is 0, and
  it may act immediately (AP permitting) — no summoning sickness.
- **If the owner researches mid-game**: the +1 attack applies to **all** their units (existing and
  future) instantly, because effective attack is computed live from the owner's tech flag, not
  baked into each unit.
- **If two units would occupy the same tile**: impossible — the Grid single-occupant invariant
  rejects the second placement (Base & Production / Movement must target empty tiles).
- **If a move would cost more AP than remains**: that destination is not offered/allowed (the AP &
  Credits Economy's `ap_can_afford` gate — movement is AP-only, unchanged by the pivot) — Unit System
  never lets a unit move "on AP credit" (colloquial "credit," not the Credits resource). This includes
  the over-cap surcharge: the *surcharged* total, not the base cost, is what `ap_can_afford` gates on.
- **If `current_hp` would exceed `hp`** (no healing source exists in the VS, but reserved): clamp at
  `hp`. Documented so a future repair/heal mechanic has a defined ceiling.
- **If Base & Production has no empty tile adjacent to the HQ to deploy a produced unit**: production
  is blocked (owned by Base & Production) — a unit cannot spawn onto an occupied or off-board tile.
- **Heavy on a flat 10-AP turn CAN produce, move, and attack the same turn — this inverts the
  pre-pivot conclusion.** Producing a Heavy now costs **7 Credits** (the resource gate) plus only
  `PRODUCE_AP_COST` = **1 AP** (the tempo surcharge) from the unit-system-owned `produce_cost`. A
  full produce→move→attack turn costs `PRODUCE_AP_COST 1 + move 3 (one tile, under cap) + attack_cost
  2 = 6 AP`, comfortably under the 10-AP floor income — **if** the player has 7 Credits banked. The
  old single-pool version of this example (produce 7 AP + move 3 + attack 2 = 12 > 10, "the Heavy is
  a turn-2+ investment") is **exactly the coupling the pivot removed**: tactical AP no longer gates
  how much Credits-side army you can afford to field, only how many actions (economic *and* tactical)
  you can fit into one turn's AP budget via each action's small surcharge. **What now actually gates
  "produce + move + attack in one turn"** is Credits affordability (`credits_can_afford(player, 7)`),
  not AP scarcity — a Heavy is a turn-1-affordable *tactical* action but may still be a turn-2+
  *economic* investment if the player hasn't banked 7 Credits yet. *(Corrected 2026-08-05 — economy
  pivot. The AC that guarded the old 12 > 10 arithmetic is corrected alongside it; see Acceptance
  Criteria.)*
- **A unit moving beyond its `soft_move_cap` (cumulative this turn)**: each tile past the cap costs
  `ceil(move_cost × SOFT_MOVE_PENALTY)`, a flat surcharge. **Worked example:** a Scout (`move_cost` 1,
  `soft_move_cap` 4, `SOFT_MOVE_PENALTY` 2.0) moving 6 tiles this turn pays `4×1 + 2×ceil(1×2.0) =
  4 + 4 = 8 AP`; the same Scout at `SOFT_MOVE_PENALTY` 1.5 pays `4×1 + 2×ceil(1×1.5) = 4 + 2×2 = 8 AP`
  (the `ceil` rounds each 1.5 up to 2). A Heavy (`move_cost` 3, cap 2, penalty 2.0) moving 3 tiles
  pays `2×3 + 1×ceil(3×2.0) = 6 + 6 = 12 AP` — over a full floor turn on movement alone, which is the
  point: bulk reach on a heavy body is expensive. *(Surcharge summation owned by Movement; the
  per-unit threshold, penalty constant, and counter are owned here.)*

## Dependencies

**Upstream (this system depends on):**

| System | Nature | Interface |
|--------|--------|-----------|
| Grid & Terrain | Hard | Unit position, occupancy, single-occupant invariant |
| Game State & Turn Manager | Hard | Stores instances; **calls** `reset_turn_flags()` / `duplicate()` (Unit owns the operations) |
| AP & Credits Economy | Hard | `ap_spend()` for move + over-cap surcharge costs; `credits_spend()` + `PRODUCE_AP_COST` (via `ap_spend()`) for produce costs (which this system owns the values of) |

**Downstream (systems that depend on this — all HARD):** Movement (`move_cost` + `soft_move_cap` +
`SOFT_MOVE_PENALTY` + `tiles_moved_this_turn`; **added the soft-cap surcharge summation formula
2026-07-20 — Movement's independent `/design-review` of that formula completed 2026-07-21 (confirming
re-review: formula confirmed sound, Approved; corrected 2026-07-22, `/review-all-gdds` — this entry was
stale**), Combat
(`hp`/effective attack/`attack_range`/`can_attack()`; **owns the cardinal-line targeting rule and the
⟶Combat targeting ACs**), Base & Production (produces units), Research (buffs attack), Command & Action
Interface, Game HUD. Each lists Unit System under its Dependencies when authored.

**Faction Identity (#12)** is also a downstream dependent (additive, identity-default):
`effective_produce_cost` (now a **Credits** value, post-pivot — `PRODUCE_AP_COST` is a flat global
surcharge and is not faction-varied) / `effective_move_cost` (AP) fold each player's faction cost
deltas, floored by the existing `MIN_MOVE_COST` (= `move_cost ≥ 1`, already Approved — no new floor
owed). Combat stats stay identity-locked (faction-identity.md CR-6). **No-op under the Neutral
default**; the fold-ins land with the asymmetry prototype. *(Reciprocity closed 2026-07-22 via
`/review-all-gdds` C-5 — see faction-identity.md Dependencies.)*

**Cross-system ownership (dependencies now designed):** Research / Tech (#8, Approved) owns
`RESEARCH_ATK_BONUS` (+1) and `DEFENSE_TECH_BONUS` (+1) — Unit System absorbed Research's handoff
2026-07-21, adding `effective_defense` and splitting the research flag into `owner_has_attack_tech` /
`owner_has_defense_tech` — this delta was re-reviewed 2026-07-21 (Accepted, Approved; corrected
2026-07-22, `/review-all-gdds` — this entry was stale). Combat (#6, Approved) owns `attack_cost` (2 AP)
and the damage formula; Base & Production (#7, Approved) owns `produce_cost` *spending flow* and
deploy-tile selection (though the cost *values* live here).

## Tuning Knobs

| Knob | VS Range | Default | Affects | If too high | If too low |
|------|----------|---------|---------|-------------|------------|
| Scout stats (hp/atk/range/move/cost) | hp 2–4 / atk 1–3 / range 1 / move 1 / cost 2–3 (Credits) | 3 / 2 / 1 / 1 / 2 | Harass & map-control identity; raw value/Credit leader | If opening is >60% Scouts or Scout wins its cost-matched trade >1:1 → rush dominates | If produced in <5% of sampled games → never worth it |
| Trooper stats | hp 5–7 / atk 3–4 / range 2 / move 2 / cost 4 (Credits) | 6 / 3 / 2 / 2 / 4 | **Efficient range-2 backbone** (best hp/Credit *among range-2 units*) | If >50% of all units built are Troopers → crowds out others | If <10% built → roster feels gapped |
| Heavy stats | hp 9–12 / atk 5–6 / range 2 / move 3 / cost 6–8 (Credits) | 10 / 5 / 2 / 3 / 7 | Anvil: **concentrated** durability + alpha on one body (not per-Credit efficiency) | If Heavy-heavy armies win >60% vs mixed → booming dominates | If Heavy built in <10% of games → too fragile/costly for its concentration premium |
| Sniper stats | hp 2–4 / atk 5–7 / range 3 / move 2 / cost 4–6 (Credits) | 3 / 6 / 3 / 2 / 5 | Glass-cannon / long-range poke identity | If Sniper kiting win-rate vs melee >60% **or outcome variance is bimodal** → oppressive | If Sniper avg. survives <1.5 turns before firing → dies before it fires |
| Per-unit `soft_move_cap` | 2–5 tiles (VS) | Scout 4 / Trooper 3 / Heavy 2 / Sniper 3 | Deep-rush / bulk-reach brake before AP surcharges | Too high → free cross-board rushes (no brake) | Too low → units feel immobile, board stalls |
| `SOFT_MOVE_PENALTY` (× `move_cost` per over-cap tile, `ceil`) | 1.5–3.0 | 2.0 | How steeply bulk over-extension is taxed | Over-extension/rushing effectively dead | No brake on rushing |
| Per-unit `attack_range` | 1–3 (VS) | 1/2/2/3 | Sightline & spacing depth; interacts with Impassable/blocking | Long ranges dominate positioning | Everything collapses to melee |
| Roster size | 4 (VS) | Scout/Trooper/Heavy/Sniper | Cognitive load vs. variety | >4–5 risks Pillar 3 overload | <3 too flat |
| Per-unit stat dimensions | 6 tracked (hp/atk/range/move/cap/cost) | 6 | Cognitive load (the *real* complexity axis, not just headcount) | >6–7 tracked values per unit risks the "spreadsheet" the fantasy forbids | — |
| `RESEARCH_ATK_BONUS` | (owned by Research) | +1 | Tech power spike | referenced — not owned here | — |
| `DEFENSE_TECH_BONUS` | (owned by Research) | +1 | Defense tech power spike (via `effective_defense`) | referenced — not owned here | — |

> **Note — `base_defense` is a schema field, not a 7th tracked legibility dimension.** Every unit
> carries a `base_defense` field (introduced via Combat's #6 handoff), but it is **0 for the entire VS
> roster** and is not a per-unit differentiator — defense enters play only as a global, research-granted
> `effective_defense` bonus, never as a stat-table column the player reads per unit. The "6 tracked
> dimensions" count above is unchanged: `base_defense` does not add to the player-facing legibility load.

> **Provisional / spike-gated:** the `soft_move_cap` and `SOFT_MOVE_PENALTY` defaults, and all four
> Sniper/range values — **plus the range-2 firing behavior of Trooper and Heavy** — are
> **unvalidated starting proposals**. The prototype was pure melee (range 1); everything with
> `attack_range > 1` (3 of the 4 units) is untested for feel. Treat these as spike outputs, not
> locked numbers (see Open Questions). The safe ranges above are the intended tuning envelope, not a
> claim the defaults are correct.

> Every stat is **data-driven** (external `.tres`/config), tunable without code changes, per the
> coding standard. The whole point of the ladder is that Credits cost buys concentration/durability/
> range while cheap units lead on raw value/Credit — keep that shape when retuning:
> **total-stat/Credit falls as cost rises** (Scout 2.50 → Trooper 2.25 → Heavy 2.14, Sniper an outlier
> dip at 1.80), which is the intended Advance-Wars-infantry shape, not a bug — expensive units justify
> themselves on range/burst/concentration, not per-Credit stats. (`PRODUCE_AP_COST` is a flat, roster-
> uniform AP surcharge and does not affect this Credits-side ladder shape.)

## Visual/Audio Requirements

Units are the primary neon "actors" on the board — the Neon Retro-Future anchor's readability rules
apply most directly here:
- **Silhouette-first (Anchor Principle 1):** Scout, Trooper, Heavy, and Sniper must be identifiable
  by **shape alone**, before color — the grayscale test. Suggested language: Scout = small, angular,
  fast-reading; Trooper = medium, balanced; Heavy = large, blocky, weighty; Sniper = thin, elongated,
  clearly "long-range" at a glance.
- **Range/line-of-fire must be visualized on selection** (owned by the Command & Action Interface):
  when a unit is selected, its valid attack targets along the four cardinal lines — and where line of
  fire is blocked, **distinguishing blocked-by-friendly from blocked-by-enemy from out-of-range** —
  must be clearly shown before committing (Pillar 3: see the shot before you take it).
- **Faction = hue (Principle 2):** a unit's color is its owner's faction hue; ownership must be
  readable across the room.
- **State readouts (owned by HUD):** current hp on the unit; a clear "has acted / spent" visual
  (e.g. dimmed) so the player sees which units are done this turn.
- **Death:** a brief neon burst on destruction (VFX owned by the combat/VFX pass).
- Audio: distinct produce, move, and death cues per weight class (specs owned by the audio pass).

> 📌 **Asset Spec** — Visual requirements are defined. After the art bible is approved, run
> `/asset-spec system:unit-system` to produce per-unit silhouette specs, dimensions, and generation
> prompts from this section.

## UI Requirements

On selection/hover, the HUD shows the unit's type, current/max hp, effective attack, move cost, and
whether it has acted this turn. The Command & Action Interface uses this to present legal actions
(move range, attack targets, and *why* a shot is blocked). Presentation is owned by those GDDs (#9,
#10); this system owns the data.

> 📌 **UX Flag — Unit System**: Unit info display and the has-acted state are core to readability.
> In Phase 4 (Pre-Production), run `/ux-design` for the core HUD/action interface **before** writing
> epics; stories should cite `design/ux/[screen].md`, not this GDD.

## Acceptance Criteria

> The **⟶Combat** ACs at the bottom test the cardinal-line/first-blocker rule the **Combat GDD (#6)
> authoritatively owns**; they are kept here for traceability but their authoritative test suite
> lives in `tests/…/combat`, **not** Unit System's Logic gate. Unit System's own gate covers only
> unit-owned data and state.

**Unit-owned — pure, headless, deterministic (Unit System Logic gate):**

- **GIVEN** each unit type is instantiated, **WHEN** its stats are read, **THEN** they match the
  table exactly — Scout (hp 3, atk 2, range 1, move 1, cap 4, `produce_cost` **Credits** 2), Trooper
  (6, 3, 2, 2, 3, 4), Heavy (10, 5, 2, 3, 2, **7**), Sniper (3, 6, 3, 2, 3, 5). *(`produce_cost` values
  are unchanged by the pivot — only their currency changed, from AP to Credits.)*
- **GIVEN** each unit type is instantiated, **WHEN** its `base_defense` field is read, **THEN** it is
  **0** for all four types (Scout / Trooper / Heavy / Sniper) — the schema default the whole VS roster
  ships with, and the value `effective_defense` reads before any Defense-Tech bonus. *(Guards the
  data-default the formula table asserts: a wrong default would silently corrupt every
  `effective_defense` output.)*
- **GIVEN** an **un-researched** owner, **WHEN** `effective_attack` is computed per type, **THEN** it
  returns the base (Scout 2, Trooper 3, Heavy 5, Sniper 6).
- **GIVEN** an owner with **Attack Tech** (`owner_has_attack_tech = true`), **WHEN** `effective_attack`
  is computed per type, **THEN** it returns `base + RESEARCH_ATK_BONUS`, where `RESEARCH_ATK_BONUS` is
  **read from Research's config, not hardcoded** (illustrative totals at +1: Scout 3, Trooper 4, Heavy
  6, Sniper 7).
- **GIVEN** an owner **without** / **with Defense Tech** (`owner_has_defense_tech` false / true),
  **WHEN** `effective_defense` is computed per type, **THEN** it returns `base_defense` (0) / `0 +
  DEFENSE_TECH_BONUS` (1) respectively — `DEFENSE_TECH_BONUS` **read from Research's config, not
  hardcoded**.
- **GIVEN** an owner with `owner_has_attack_tech = true` **and** `owner_has_defense_tech = false`,
  **WHEN** both effective values are computed, **THEN** `effective_attack` returns `base_attack +
  RESEARCH_ATK_BONUS` **and** `effective_defense` returns `base_defense` **unmodified** (0); **AND
  GIVEN** the flags reversed (`owner_has_attack_tech = false`, `owner_has_defense_tech = true`),
  **THEN** `effective_defense` returns `base_defense + DEFENSE_TECH_BONUS` **and** `effective_attack`
  returns `base_attack` **unmodified** — proving the two flags act **independently**, not as a shared
  toggle. *(Locks in the two-flag split's whole purpose: a regression that re-couples the flags fails
  this AC.)*
- **GIVEN** an owner with **both** `owner_has_attack_tech` **and** `owner_has_defense_tech` true,
  **WHEN** both effective values are computed, **THEN** `effective_attack = base_attack +
  RESEARCH_ATK_BONUS` **and** `effective_defense = base_defense + DEFENSE_TECH_BONUS` **simultaneously**
  — neither bonus suppresses the other (additive, non-interacting).
- **GIVEN** an instance created **before** its owner researches, **WHEN** the owner's **Attack-Tech**
  flag flips to true (same instance, no new unit), **THEN** a later `effective_attack` call on that
  instance returns `base + RESEARCH_ATK_BONUS`; **AND** independently, **WHEN** the owner's
  **Defense-Tech** flag flips to true, **THEN** a later `effective_defense` call returns `base_defense +
  DEFENSE_TECH_BONUS` — both proving the effective values are computed **live** from tech state, not
  baked at construction. *(Both flags must be exercised — one live-flip test per flag.)*
- **GIVEN** a unit at `current_hp == hp`, **WHEN** its sole hp mutator `apply_hp_delta(unit, +N)`
  (`N > 0`) is called (the path Combat and any future heal use; not raw field assignment), **THEN**
  `current_hp` clamps at `hp` and never exceeds it.
- **GIVEN** a freshly constructed unit, **WHEN** `has_attacked` and `tiles_moved_this_turn` are read,
  **THEN** they are `false` and `0` (no summoning sickness at the data level).
- **GIVEN** a unit with `has_attacked == true`, **WHEN** `can_attack(unit)` is read, **THEN** it
  returns `false`; **AND GIVEN** `has_attacked == false`, **THEN** it returns `true`. *(Pure
  Unit-owned guard per Rule 2a — Combat reads it but Unit owns and tests it.)*
- **GIVEN** a unit with `has_attacked == true`, **WHEN** `reset_turn_flags(unit)` is called on the
  bare instance, **THEN** `has_attacked` becomes `false` and `tiles_moved_this_turn` becomes `0`
  (pure per-instance method — no Turn Manager object required).
- **GIVEN** N units are instantiated in one game state, **WHEN** their `entity_id`s are compared,
  **THEN** all N are pairwise distinct (uniqueness is scoped to a single game state).
- **GIVEN** a `UnitStats` resource **constructed in-memory in the test** (injected, not loaded from
  disk) with `Trooper.hp = 99`, **WHEN** a Trooper is instantiated from it, **THEN** `unit.hp == 99`
  — proving stats flow from injected external data, no hardcoded constants, no file I/O.
- **GIVEN** unit A, **WHEN** `duplicate(A)` produces B and A's `current_hp`, `position`,
  `has_attacked`, and `tiles_moved_this_turn` are each mutated, **THEN** B's are unchanged; **AND
  WHEN** B's are mutated instead, **THEN** A's are unchanged (bidirectional independence). `owner`,
  `entity_id`, and `type` compare **equal** across the clone (value/identity preserved and
  intentionally shared — the clone is a parallel non-coexisting state, per Rule 2a — not aliased
  mutable state).
- **GIVEN** the ladder constants under the dual-cost model, **WHEN** `PRODUCE_AP_COST` (1) +
  one-tile move (`move_cost` 3) + Combat `attack_cost` (2) are summed for a Heavy, **THEN** the AP
  total (6) is **within** the flat 10-AP floor income, **AND** Heavy `produce_cost` (7) is checked
  **separately** against `current_credits` — a pure arithmetic regression guard proving the two pools
  are summed independently, never combined into one total. *(Corrected 2026-08-05 — economy pivot;
  supersedes the pre-pivot AC that summed all three costs as AP and asserted 12 > 10. The point this
  AC preserves is ordering/independence: AP and Credits affordability are two separate gates checked
  against two separate pools, never added together — a regression that summed `produce_cost` into the
  AP total would silently reintroduce the old single-pool coupling and must fail this AC.)*

**Integration — require Grid + AP & Credits Economy + Movement/Combat (not the pure Unit gate):**

- **GIVEN** a unit at `current_hp` 0, **WHEN** resolution completes, **THEN** it transitions to
  Destroyed, is removed from Grid occupancy that step, and its tile is empty (Unit + Grid; a fake
  Grid is fine, independent of how the damage was applied).
- **GIVEN** a unit produced this turn with sufficient AP, **WHEN** a move/attack is issued for it the
  same turn, **THEN** it succeeds (no summoning sickness, end-to-end).
- **GIVEN** a unit with `has_attacked == true` and sufficient AP, **WHEN** a move is issued, **THEN**
  it succeeds and the unit's position changes (movement is never gated by the attack flag).
- **GIVEN** an owner with less AP than a candidate move's **surcharged** total cost, **WHEN** the
  move is attempted, **THEN** it is rejected, **no AP is spent**, and the unit's position is
  unchanged (never moves "on credit").
- **GIVEN** a unit moving past its `soft_move_cap` cumulative this turn, **WHEN** total move cost is
  computed, **THEN** tiles beyond the cap are billed at `ceil(move_cost × SOFT_MOVE_PENALTY)` each
  and the cumulative counter is *not* reset by splitting the move into multiple calls (surcharge
  formula owned by Movement; this AC lives with Movement's suite, referenced here for traceability).

**⟶Combat — authoritative test lives in the Combat GDD's suite:**

- **GIVEN** a Sniper (range 3) with an enemy exactly 3 tiles away in a cardinal direction and no
  intervening piece, **WHEN** it attacks that direction, **THEN** the enemy is a legal target.
- **GIVEN** a friendly unit or Impassable tile between an attacker and an enemy in a cardinal
  direction, **WHEN** legal targets are computed, **THEN** that enemy is **not** targetable (only the
  first blocker in each direction is considered).
- **GIVEN** two enemies stacked in the same cardinal line within range, **WHEN** the unit attacks
  that direction, **THEN** only the nearest is hit (no pierce/shoot-through).

## Open Questions

| Question | Owner | Notes / target |
|----------|-------|----------------|
| **Ranged combat is UNVALIDATED** — the prototype was all melee (range-1). Does the cardinal-line/first-blocker model feel good, and are the ranges/stats balanced? **Note this is 3 of 4 units** (Trooper/Heavy range 2, Sniper range 3), not just the Sniper — Trooper/Heavy range-2 firing (incl. friendly units blocking your own shots) is equally untested. | game-designer / Combat (#6) | **Highest risk in this GDD.** Validate the whole `range>1` model in the vertical slice or a focused combat spike before committing |
| **Does the Sniper have any counter on this ladder?** Best atk/Credit + longest range (3) + no Zone-of-Control (Movement) + unrestricted move→attack→move means it can plausibly fire from outside every other unit's counter-range, with no piece that both reaches it and survives the trade. | game-designer / Combat (#6) | **Named spike hypothesis (structural, not just tuning).** Design the spike to look for a *no-counter* result and to measure **outcome variance / dispersion**, not just mean win-rate — the Sniper is bimodal (oppressive or dead). If structural, tuning alone won't fix it; the ZoC / friendly-fire-blocking / move-then-attack-restriction levers are the candidate fixes |
| Should any unit get shoot-through/pierce, or diagonal fire? | Combat (#6) | VS = cardinal only, first blocker only; pierce/diagonal are Alpha levers |
| Does line-of-fire blocking make Impassable terrain / Procedural Center bands too strong (sightline walls)? | game-designer / Grid | Watch in playtest — interacts with Grid's Impassable + cover |
| **Does the soft-cap brake need a companion *kiting* tax?** The soft cap only bites on deep single-turn over-extension (rushes); a 1–2 tile standoff kite sits under every cap and is untaxed by design. If Sniper/ranged kiting proves oppressive in the spike, a *separate* anti-kite lever (ZoC, move-then-attack cost, etc.) — not a lower soft cap — is the tool. | game-designer / Combat (#6) / Movement (#5) | Deliberately **out of scope** for the soft cap. Reframed 2026-07-20: soft cap = rush/over-extension brake, honestly named; kiting is its own spike question |
| Any healing / repair source? | game-designer | None in VS; hp clamp at max reserved for future |
| Per-faction unit rosters or stat variants? | Faction Identity (#12) | Natural asymmetry lever; keep shallow until the asymmetry prototype |
| Per-unit veterancy / XP? | game-designer | Out of VS scope; noted as a possible progression hook |
| Should Heavy have splash/AoE attacks? | Combat (#6) | Ties to the turn manager's reserved "simultaneous HQ destruction" rule; Alpha consideration |
| **Soft-cap surcharge formula added to Movement (2026-07-20).** Unit owns `soft_move_cap`, `SOFT_MOVE_PENALTY`, and the `tiles_moved_this_turn` counter; Movement (#5) has added the surcharge summation: tiles past the cap (cumulative this turn) billed at `ceil(move_cost × SOFT_MOVE_PENALTY)`, a flat single-step surcharge, reading the counter and honoring the `ceil` integer-AP rule. | Movement (#5) | **Handoff complete and re-reviewed — formula authored in `move_path_cost`, confirmed sound in Movement's 2026-07-21 independent `/design-review` (Approved; corrected 2026-07-22, `/review-all-gdds` — this entry was stale).** |
| **Does cost-7 Heavy actually get built?** Raising Heavy 6→7 gave the Trooper the range-2 hp/Credit niche but left the Heavy with *no* per-Credit niche (worst atk/Credit in the roster), standing entirely on concentration. Is concentration enough to justify the price, or is the Heavy dead? | game-designer / economy-designer | Validate build-rate in the slice (doc's own "if <10% built → too costly" threshold). If dead, retune (cost or stats) — kept as a doc-level identity for now, not a rebalance |
| ~~Odd `produce_cost` friction (Sniper 5 AND Heavy 7)~~ — **RESOLVED by the 2026-08-05 economy pivot.** Under the old single AP pool, a full Sniper turn (produce 5 + move 2 + attack 2 = 9 of 10) or Heavy produce+attack (7 + 2 = 9) each stranded 1 AP. Since `produce_cost` moved to Credits and only a flat `PRODUCE_AP_COST` (1) hits the AP budget, the AP-side arithmetic changed entirely (e.g. Sniper: 1 + move 2 + attack 2 = 5 of 10 AP) and this specific friction no longer exists. Any *Credits*-side "leftover" friction is a new, unstudied question — not yet raised as a spike target. | game-designer / Combat (#6) | Closed as moot by the pivot; re-open only if a new Credits-side spend-friction pattern surfaces in playtest |
| **`soft_move_cap` / `SOFT_MOVE_PENALTY` defaults are unvalidated** (the ranged/reach model was never in the prototype). | game-designer / Movement (#5) | Tune in the ranged-combat spike alongside the Sniper/range numbers |
