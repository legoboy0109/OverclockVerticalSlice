# AP & Credits Economy

> **Status**: **In Revision — PIVOT 2026-08-05.** The original single-AP-pool model (Approved
> 2026-07-22) is **split into two resources**: **AP** (a flat, per-turn *tactical* budget for
> moving/attacking, with limited carryover) and **Credits** (a *banked economic* currency that funds
> producing, building, and researching). This decouples economic investment from battlefield tempo —
> growing your economy no longer drains the budget you fight with. This revision **supersedes** the
> single-pool design; the diminishing-outpost income formula is preserved verbatim, only re-denominated
> from AP into Credits. **Pending:** `/design-review` on this delta; `/propagate-design-change`
> (ADR-0006 spend-contract, ADR-0008 start-of-turn); satellite-GDD propagation
> (game-state-turn-manager, base-production, ai-opponent); ⚠ **Pillar 1 wording** (see Open Questions).
> **Author**: user (design pivot) + main session (systems-designer / economy-designer formula carry-over)
> **Last Updated**: 2026-08-05 (two-resource pivot — AP flat+carryover; Credits banked economy; dual-cost logistics)
> **Implements Pillar**: Pillar 2 (Tempo Is the Skill) — AP is per-turn tempo; the economic-investment
> axis is Credits. ⚠ **Pillar 1 ("One Economy, Every Choice") is revised by this pivot** — there are now
> two resources by design. The intent Pillar 1 protected (every spend is a real tradeoff) is preserved
> across two axes; the *wording* needs a decision (Open Questions).
> **Priority / Layer**: Vertical Slice / Foundation (system #3)

## Overview

The economy runs on **two resources**, each owning a distinct decision axis:

- **AP (Action Points)** — a **flat tactical budget** granted every turn (default **10**), spent on
  **moving and attacking**, plus a **small AP surcharge on each economic action** so building an army
  still costs a slice of your turn. Unspent AP **carries over into your next turn up to a cap**
  (default **5**), so you can bank a little tempo without stockpiling a burst. AP is predictable
  battlefield rhythm: it does not depend on your economy.
- **Credits** — a **banked economic currency**. Each turn a player earns Credit **income** (a flat
  base plus a **diminishing** bonus per *completed* outpost — the exact curve that used to drive AP),
  and Credits **accumulate across turns with no cap** (a war chest). Credits are the **primary cost**
  of producing units, building structures, and researching.

**Economic actions cost both**: their Credit price (the resource gate — can you afford it) and a small
AP surcharge (the tempo gate — how many economic actions fit in one turn). The purpose of the split is
Pillar 2 made cleaner: **AP is stable tactical tempo, Credits are accumulating strategic investment**,
and the two no longer compete in one pool. This system owns both pools, both start-of-turn behaviors,
and the shared afford/spend framework; the individual action costs live in the systems that charge them.

## Player Fantasy

Every turn poses **two kinds of decision**, cleanly separated:

- **Tactical (AP):** "What does my army *do* this turn?" You have a fixed, always-present budget —
  never quite enough to move and attack with *everyone* — so you pick your battles. Because AP no
  longer bleeds into economy, this decision is about the board, not bookkeeping. The **carryover**
  lets you hold back a turn to strike harder the next, a small tempo-banking skill.
- **Strategic (Credits):** "When do I *invest*?" Credits pile up in a war chest, so the tension is
  *timing* — boom now for compounding income, army up for pressure, or tech for a permanent edge —
  and **when** to spend the pile you've saved. The small AP surcharge means you can't dump the whole
  war chest in one turn; expansion is paced by your tactical budget too.

The old fantasy — *"one pool, never quite enough for everything"* — becomes **"a stable tactical
rhythm punctuated by strategic commitments."** AP still creates per-turn pressure (10 AP + a little
carry doesn't stretch to everything you'd like to do); Credits create the save-up-and-spend arc that
single-pool AP couldn't. The felt result: a commander who fights with a steady hand (AP) and *invests*
with deliberate timing (Credits) — the coupling that made "I built something, now I can't act" feel bad
is gone by design.

## Detailed Design

### Core Rules

**AP — the tactical pool**

1. **AP is a flat per-turn budget, not income-driven.** At a player's start-of-turn reset,
   `current_ap := FLAT_AP_PER_TURN + min(ap_leftover, AP_CARRYOVER_CAP)`, where `ap_leftover` is the AP
   this player had unspent at the end of their previous turn. AP does **not** scale with the economy.
2. **Limited carryover.** Unspent AP is **not discarded** — it carries into the next turn's reset, but
   only up to `AP_CARRYOVER_CAP` (default 5); any leftover beyond the cap is lost. Max AP at the start
   of any turn is therefore `FLAT_AP_PER_TURN + AP_CARRYOVER_CAP` (default 15). This rewards holding
   back a turn without enabling an unbounded alpha-strike stockpile.
3. **AP pays for tactics, plus a logistics surcharge.** Move (`move_cost` 1/2/3) and attack
   (`attack_cost` 2) spend AP. Each economic action *also* spends a small AP surcharge —
   `PRODUCE_AP_COST` (1) to produce a unit, `BUILD_AP_COST` (2) to build a structure, and a **per-tech**
   research surcharge to research (`RESEARCH_AP_COST`, **base 1**, overridable per research option so a
   quick tech and a heavy tech can tax the turn differently — Research owns each tech's override) — so
   nearly every action draws some AP, and the AP surcharge rate-limits how many economic actions fit in
   one turn even with a full Credit war chest.
4. **`ap_spend(player, amount)` is the sole mutator of `current_ap`, and is atomic**: it validates
   (`player` is the active player, `0 ≤ amount ≤ current_ap`), deducts the full amount, and returns
   success — or changes nothing and returns failure. A spend against a non-active player's pool is
   rejected. No partial spend. `ap_spend(0)` is a no-op success; a negative amount is rejected. AP
   Economy has **no** concept of "this unit already acted" — the once-per-unit-per-turn attack flag is
   Combat's.
5. **AP invariant:** `0 ≤ current_ap ≤ FLAT_AP_PER_TURN + AP_CARRYOVER_CAP` at every observable point.
   `current_ap` only *decreases* (via `ap_spend`) during the active player's turn and only *increases*
   at their own start-of-turn reset. Only the active player's pool is mutable. **Writer contract:**
   `current_ap` is written by exactly two paths — the start-of-turn **reset** (Game State & Turn
   Manager) and **`ap_spend()`** (this system). Nothing else writes it directly.

**Credits — the economic pool**

6. **Credits are a banked pool that accumulates.** At a player's start-of-turn reset,
   `current_credits += credit_income(player)` — income is **added**, never a reset-to-snapshot, and
   there is **no cap and no discard**. A war chest carries indefinitely until spent. (Contrast AP,
   which is flat-with-capped-carry.)
7. **Credit income is a diminishing function of *completed* outposts, evaluated once at start-of-turn.**
   `credit_income` is computed at the player's start-of-turn reset **after** build completions (so an
   outpost that completes this turn counts this turn) and added to the pool; it is not recomputed
   mid-turn. Only **completed** outposts count (Rule 8). This is the identical curve that formerly drove
   AP income, re-denominated into Credits (see Formulas).
8. **Under-construction outposts do not produce income.** Outposts (and research) have a **build time**
   (owned by Base & Production / Research); they sit under construction before completing. Only
   **completed** outposts are counted. An outpost destroyed while under construction never contributes
   income, and the **Credits** spent on it are **not refunded** — that lost investment is the tactical
   punish for over-committing to a boom.
9. **`credits_spend(player, amount)` is the sole mutator of `current_credits`, atomic and
   active-player-gated** — a mirror of `ap_spend` (validates active player + `0 ≤ amount ≤
   current_credits`, deducts fully or not at all). **Writer contract:** `current_credits` is written by
   exactly three paths — the start-of-turn **income add**, **`credits_spend()`**, and **`credits_credit()`**
   (the cancel-build refund, Base & Production). Nothing else writes it directly.
10. **Credits invariant:** `current_credits ≥ 0` at every observable point; it *increases* at
    start-of-turn (income) and on a cancel refund, and *decreases* via `credits_spend`. Never negative.
    Only the active player may spend their Credits.

**Dual-cost logistics (the AP×Credits gate)**

11. **Economic actions cost both Credits and AP, atomically.** Producing, building, and researching
    each carry a **Credit cost** (the resource price, owned by the acting GDD) *and* an **AP surcharge**
    (Rule 3). The action is **legal only if the player can afford both** (`credits_can_afford` AND
    `ap_can_afford`), and applying it spends **both or neither** (a single atomic commit — never spend
    Credits then fail the AP leg, or vice versa). This is the enforcement point for the pivot's core
    feel: a full war chest cannot bypass the tactical budget, and a full AP bar cannot conjure units
    without Credits.
12. **Deterministic.** Both pools mutate on the turn manager's single-action path; the same starting
    balances and the same ordered action sequence always yield the same AP and Credit trajectories. No
    RNG.

### States and Transitions

Neither pool has a discrete state machine — each is an integer with its invariant. Their lifecycles
across a turn:

**AP (flat + capped carryover):**

| Moment | Effect on `current_ap` |
|--------|------------------------|
| Player's start-of-turn reset | `current_ap ← FLAT_AP_PER_TURN + min(ap_leftover, AP_CARRYOVER_CAP)` |
| Each `ap_spend(amount)` during the turn | `current_ap ← current_ap − amount` (only on success; never below 0) |
| Player's end-of-turn | No discard — the unspent `current_ap` becomes `ap_leftover`, consumed (capped) at the **next** reset |
| Opponent's turn | This player's `current_ap` is immutable; only the active player's pool may be spent |

**Credits (banked, accumulating):**

| Moment | Effect on `current_credits` |
|--------|-----------------------------|
| Player's start-of-turn reset | `current_credits ← current_credits + credit_income(player)` (added; no cap) |
| Each `credits_spend(amount)` during the turn | `current_credits ← current_credits − amount` (only on success; never below 0) |
| Cancel own under-construction build | `current_credits ← current_credits + floor(build_cost × CANCEL_REFUND_RATE)` (Base & Production) |
| Player's end-of-turn | No change — Credits bank indefinitely |
| Opponent's turn | Immutable by the opponent; only the active player may spend |

### Interactions with Other Systems

| System | Data in | Data out | Interface owner |
|--------|---------|----------|-----------------|
| Game State & Turn Manager | at start-of-turn: resets AP (flat + capped carry) **and** adds Credit income; stores `current_ap` + `current_credits`; calls the spend primitives in `apply_action` | — | Turn manager owns timing + storage; AP & Credits Economy provides `credit_income()`, `ap_spend()`/`ap_can_afford()`, `credits_spend()`/`credits_can_afford()` |
| Base & Production | `completed_outpost_count(player)` (alive, owned, **Economy Outposts only**, status = completed); owns each structure's **Credit** `build_cost`, build time, under-construction state, and `CANCEL_REFUND_RATE` (Credit refund) | `credit_income` reads the completed count; build spends Credits + `BUILD_AP_COST`; produce spends Credits + `PRODUCE_AP_COST` | Base & Production owns outposts/costs; this system reads the count and provides both spend primitives |
| Research / Tech | owns each tech's **Credit** research cost + build time + effects, incl. **Economy Tech's `ECONOMY_TECH_INCOME_BONUS`** added to `credit_income` | research spends Credits + `RESEARCH_AP_COST`; `credit_income` reads the Economy Tech term | Research owns cost/effect; this system owns the pools + `credit_income` formula |
| Movement / Combat / Unit | each owns its own **AP** costs (`move_cost`, `attack_cost`, over-cap surcharge) | `ap_can_afford`/`ap_spend` calls | those systems own their AP costs |
| Faction Identity | optional faction income deltas (`Δ_base`/`Δ_tier1`/`Δ_tier2`) now fold into **`credit_income`** (was `ap_income`); the `BASE_INCOME_FLOOR` guard applies to Credit income | credit income deltas | Faction owns the deltas; this system owns the fold-in + floor |
| Command & Action Interface / Game HUD | `current_ap`, `current_credits`, both incomes/carryover, both afford queries per action | affordability (both pools) drives which actions are offered/highlighted | those systems own presentation |

**Public interface:** `credit_income(player) -> int` · `ap_can_afford(player, amount) -> bool` ·
`ap_spend(player, amount) -> bool` · `credits_can_afford(player, amount) -> bool` ·
`credits_spend(player, amount) -> bool` · `credits_credit(player, amount) -> void`. (`current_ap(player)`
and `current_credits(player)` reads live on the game state.)

## Formulas

### `credit_income(player)` — per-turn Credit income

Identical in shape to the former `ap_income` — only the resource it grants changed (AP → Credits):

`credit_income(player) = BASE_INCOME + OUTPOST_BONUS_TIER1 × min(n, TIER_THRESHOLD) + OUTPOST_BONUS_TIER2 × max(0, n − TIER_THRESHOLD) + (has_economy_tech(player) ? ECONOMY_TECH_INCOME_BONUS × min(n, ECONOMY_TECH_TIER_THRESHOLD) : 0)`

`where n = max(0, completed_outpost_count(player))`

> **Economy Tech term (Research-owned).** A player holding **Economy Tech** earns an extra
> `ECONOMY_TECH_INCOME_BONUS` (1) Credit/turn **per completed Economy Outpost, up to
> `ECONOMY_TECH_TIER_THRESHOLD` (6)**, then nothing further. `ECONOMY_TECH_INCOME_BONUS` is owned by
> Research; `ECONOMY_TECH_TIER_THRESHOLD` is this system's brake on the term (mirroring how
> `TIER_THRESHOLD` caps the base curve), so the diminishing-returns shape is not silently defeated. The
> tiering rationale carries over unchanged from the single-pool design — the term is capped so past
> `n = 6` the combined marginal returns to +1/outpost.

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `BASE_INCOME` | — | int const | 10 | Flat Credits every player earns each turn regardless of board state |
| `OUTPOST_BONUS_TIER1` | — | int const | 2 | Credits per outpost for outposts 1–`TIER_THRESHOLD` |
| `OUTPOST_BONUS_TIER2` | — | int const | 1 | Credits per outpost beyond `TIER_THRESHOLD` (diminished tier) |
| `TIER_THRESHOLD` | — | int const | 4 | Number of outposts earning the full bonus before diminishing |
| `n` | `max(0, completed_outpost_count(player))` | int | 0 – (board-limited) | Count of the player's completed, alive Economy Outposts (HQ/Production/Defensive excluded; under-construction excluded), clamped at 0 |
| `ECONOMY_TECH_INCOME_BONUS` | — | int const | 1 | Credits/turn per completed Economy Outpost (up to the threshold) while Economy Tech is held — **owned by Research** |
| `ECONOMY_TECH_TIER_THRESHOLD` | — | int const | 6 | Outposts the Economy Tech bonus applies to before it stops accruing — this system's brake |
| `credit_income` | — | int | 10 – ~32 | Credits added at the player's next start-of-turn reset |

**Output range:** floor 10 (n = 0). Outposts 1–4 add +2 each; 5+ add +1 each; ~26/turn practical without
Economy Tech, **~32** with it (tech term capped at 6 outposts).
**Worked examples (no Economy Tech):** n=0 → 10; n=2 → 14; n=4 → 18; n=5 → 19; n=8 → 22; n=12 → 26.
**Worked examples (Economy Tech held):** n=2 → 16; n=4 → 22; n=5 → 24; n=6 → 26; n=8 → 28; n=12 → 32.

> These are now **Credits per turn added to a banked pool**, not an AP reset value. Because Credits
> accumulate, the *stock* a player can hold is unbounded even though the *income rate* is capped — see
> the snowball Open Question, which the pivot re-opens (banking enables larger spending bursts than a
> use-it-or-lose-it pool did).

### AP reset — flat with capped carryover

```
# Evaluated at the player's start-of-turn reset (Game State & Turn Manager owns the timing).
ap_at_reset(player) = FLAT_AP_PER_TURN + min(ap_leftover(player), AP_CARRYOVER_CAP)
# where ap_leftover(player) = the player's current_ap at the end of their previous turn (never discarded).
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `FLAT_AP_PER_TURN` | int const | 10 | Flat AP granted every turn (tactical budget floor) |
| `AP_CARRYOVER_CAP` | int const | 5 | Max unspent AP that carries into the next turn |
| `ap_leftover` | int | 0 – (FLAT+CAP) | The player's unspent AP at their previous end-of-turn |
| `ap_at_reset` | int | 10 – 15 | AP the player holds at the start of their turn |

**Worked examples:** leftover 0 → 10; leftover 3 → 13; leftover 5 → 15; leftover 8 → 15 (capped);
leftover 12 → 15 (capped).

### The afford/spend gates (both pools)

```
# Pure queries — no mutation, no active-player gate (safe to ask about any player: AI eval / HUD).
ap_can_afford(player, amount)      = (amount >= 0) AND (amount <= current_ap(player))
credits_can_afford(player, amount) = (amount >= 0) AND (amount <= current_credits(player))

# Sole mutators — atomic, gated on active-player (only the active player's pools are spendable).
ap_spend(player, amount):        # identical shape to credits_spend
    if player != active_player(state):  return false
    if amount < 0:                      return false
    if amount == 0:                     return true
    if amount > current_ap(player):     return false
    current_ap(player) -= amount;       return true

credits_spend(player, amount):
    if player != active_player(state):       return false
    if amount < 0:                           return false
    if amount == 0:                          return true
    if amount > current_credits(player):     return false
    current_credits(player) -= amount;       return true
```

### Dual-cost legality (economic actions)

```
# An economic action A carries (credit_cost, ap_cost). It is legal iff BOTH pools can pay,
# and applying it is a single atomic both-or-neither commit.
legal(A, player) = credits_can_afford(player, A.credit_cost) AND ap_can_afford(player, A.ap_cost)
apply(A, player):                                  # both-or-neither
    if not legal(A, player): return false
    credits_spend(player, A.credit_cost)           # both guaranteed affordable by the legal() gate above,
    ap_spend(player, A.ap_cost)                     # so neither leg can fail after the check
    return true
```

> **Action costs are owned by their GDDs.** The **Credit** costs — *produce 2/4/5/7 (Scout/Trooper/
> Sniper/Heavy), build 4/9/6/8 (Economy/Production/Defensive/Research), research 7/10/10 (Economy/
> Attack/Defense)* — are quoted illustratively; the owning GDD (and the entity registry) is the single
> source of truth. Their **AP surcharges** (`PRODUCE_AP_COST`/`BUILD_AP_COST`/`RESEARCH_AP_COST`) are
> owned **here** (they are a property of the tactical budget, not of any one structure). Move (1/2/3)
> and attack (2) remain AP-only, owned by Movement/Combat.

## Edge Cases

- **AP leftover exceeds the cap:** only `AP_CARRYOVER_CAP` (5) carries; the rest is lost (e.g. end a
  turn with 9 unspent → next turn starts at `10 + min(9, 5) = 15`, not 19).
- **Full Credit war chest but 0 AP:** an economic action is **illegal** — the AP surcharge is
  unaffordable. This is the intended tempo gate: you cannot dump the war chest in one turn.
- **Plenty of AP but insufficient Credits:** the economic action is **illegal** — Credits are the
  resource gate.
- **Dual-cost action affordable in only one pool:** illegal; **nothing is spent** from either pool
  (both-or-neither atomicity — never a half-commit).
- **Credits are never discarded:** unspent Credits bank into the next turn (and forever) — the next
  turn starts at `current_credits + income`, not just `income`.
- **An outpost is built this turn:** it enters under construction — Credit income is **unchanged this
  turn** (completed-only rule); it contributes only after it completes, counted at a subsequent
  start-of-turn reset (the completing turn itself, since income is added after build-timer advance).
- **A completed outpost is destroyed** (usually during the opponent's turn): no Credits are refunded;
  the income loss is picked up at the owner's next start-of-turn reset.
- **An under-construction outpost/research is destroyed:** it never produces income/effect and the
  **Credits** spent on it are **not refunded** (the boom punish). The **AP surcharge** was also spent
  and is likewise gone (you spent the tempo).
- **Voluntarily cancelling one's own under-construction build:** `floor(build_cost × CANCEL_REFUND_RATE)`
  **Credits** are refunded (Base & Production owns the rate, default 0.5); the **AP surcharge is not
  refunded**.
- **`n` crosses the tier boundary (4 → 5):** the 5th outpost adds only +1 Credit income, not +2.
- **`ap_spend(0)` / `credits_spend(0)`:** no-op, returns true. A negative amount to either is rejected.
- **`completed_outpost_count` returns negative** (caller bug): `n` clamps to 0; income floors at
  `BASE_INCOME` (10); Credits never go sub-floor.

## Dependencies

**Upstream (this system depends on):**

| System | Nature | Interface |
|--------|--------|-----------|
| Game State & Turn Manager | Hard | Stores `current_ap` + `current_credits`; at start-of-turn resets AP (flat + capped carry) and adds Credit income; calls the spend primitives inside `apply_action` |

**Downstream (systems that depend on this — all HARD):** Unit System, Movement, Combat (AP costs via
`ap_spend`), Base & Production, Research (Credit costs via `credits_spend` + the AP surcharge), Command
& Action Interface, Game HUD (display both pools + both incomes/carryover), AI Opponent
(`ap_can_afford`/`credits_can_afford`/`credit_income` gate and score every candidate — see the AI
two-currency scoring note in ai-opponent.md), and the turn manager. Each, when authored/revised, lists
this system under its Dependencies.

**Base & Production** — provides `completed_outpost_count(player)` (alive, owned, Economy Outposts only,
completed). Owns each structure's **Credit** `build_cost`, build time, the under-construction/destroyable
state (no refund on destruction), and `CANCEL_REFUND_RATE` (a **Credit** refund on voluntary cancel).

**Research / Tech** — owns each tech's **Credit** research cost, build time, and effect; spends Credits +
`RESEARCH_AP_COST`. The Economy-Tech income term lands in `credit_income`.

**Faction Identity** — the optional faction income deltas now fold into `credit_income` (no-op under the
VS Neutral/empty-delta default); the `BASE_INCOME_FLOOR` guard applies to Credit income.

## Tuning Knobs

| Knob | VS Range | Default | Affects | If too high | If too low |
|------|----------|---------|---------|-------------|------------|
| `FLAT_AP_PER_TURN` | 6–14 | 10 | Per-turn tactical tempo (moves/attacks/turn) | Every unit acts every turn; no tactical scarcity | Turns feel starved; can barely act |
| `AP_CARRYOVER_CAP` | 0–10 | 5 | How much tempo you can bank for a bigger turn | Alpha-strike stockpiling; bursty, swingy | No reward for holding back; pure use-it-or-lose-it |
| `PRODUCE_AP_COST` | 0–3 | 1 | Tempo cost / per-turn rate limit on producing | Producing crowds out fighting | Free production; war chest dumps in one turn |
| `BUILD_AP_COST` | 0–4 | 2 | Tempo cost of building a structure | Building crowds out fighting | Booming has no tactical cost |
| `RESEARCH_AP_COST` | 0–4 | 1 (base; **per-tech overridable** — Research owns each tech's surcharge, defaulting to this base) | Tempo cost of researching | Teching crowds out fighting | Teching has no tactical cost; AI under-values research (a base of 2 pushed Defense Tech to a razor-thin AI margin — see ai-opponent.md, hence base 1) |
| `BASE_INCOME` | 6–14 | 10 | Baseline Credit income; what you can afford with zero economy | Rushing trivially funded; economy pointless | Every turn credit-starved |
| `OUTPOST_BONUS_TIER1` | 1–3 | 2 (1–4) | Boom payoff / ROI | Booming dominates; snowball | Booming never worth it |
| `OUTPOST_BONUS_TIER2` | 0–2 | 1 (5+) | Late-economy ceiling / snowball brake | Runaway leader (Pillar 2 risk) | Over-building pointless past 4 |
| `TIER_THRESHOLD` | 3–6 | 4 | Where diminishing returns start | Near-linear boom | Booming capped too early |
| `ECONOMY_TECH_TIER_THRESHOLD` | 4–8 | 6 | Outposts the Economy Tech term applies to | Restores untiered snowball | Economy Tech feels weak |
| `ECONOMY_TECH_INCOME_BONUS` | — | 1 (Research-owned) | Per-outpost Credit/turn value of Economy Tech | see `research-tech.md` | see `research-tech.md` |

> **New pivot knobs** are the first five. `FLAT_AP_PER_TURN` + `AP_CARRYOVER_CAP` set the tactical
> rhythm; the three `*_AP_COST` surcharges set how strongly logistics competes with fighting for the
> tactical budget. `RESEARCH_AP_COST` is only the **base default** — each research option may override
> its own AP surcharge (Research owns the per-tech value), so techs can carry different tempo costs. **All five are the most playtest-sensitive numbers in the pivot** — they replace the
> old "how much can I do per turn" balance that a single pool implicitly set. Credit costs of
> units/structures/tech live in their owning GDDs (unchanged values, re-denominated to Credits).

## Visual/Audio Requirements

The economy is felt through the HUD (presentation owned by Game HUD / Command interface):
- **Two counters, distinct and both prominent:** an **AP counter** (with a start-of-turn "fill"
  flourish to the flat value, plus any carry, and a tick-down on each spend) **and** a **Credits
  counter** (accumulating; a start-of-turn "+income" flourish, ticking down on economic spends). The
  player must always feel both budgets and never confuse them.
- **Both incomes / carryover legible on demand:** the Credit income breakdown (base + outpost +
  econ-tech) and the AP carryover ("+N carried, capped at 5") so the player understands each number.
- **Dual-cost affordability:** an economic action's preview shows **both** costs (e.g. "9 ⛁ + 2 AP")
  and greys out if **either** is unaffordable, with the binding pool made clear.
- **Neon Retro-Future note:** both resource counters and affordability highlights are first-class,
  high-saturation UI ("neon means this matters"). AP and Credits should read as visually distinct
  (e.g. different hue families) so tempo vs. war-chest never blur.
- Audio: distinct start-of-turn cues for the AP fill and the Credit income, and per-spend ticks (specs
  owned by the audio pass).

## UI Requirements

The HUD displays `current_ap`, `current_credits`, the AP carryover, and the Credit income; the Command
& Action Interface uses `ap_can_afford` **and** `credits_can_afford` to decide which actions are shown
available vs. greyed, and shows both costs on economic actions. Presentation/interaction owned by those
two GDDs; this system owns the data and the two afford queries.

> 📌 **UX Flag**: the two counters, the Credit income breakdown, the AP carryover indicator, and
> dual-cost affordability are central to readability — the pivot **adds a whole second resource to the
> HUD**. Re-run `/ux-design` on the core HUD (`design/ux/hud.md`) before writing pivot epics; stories
> cite the UX spec, not this GDD.

## Acceptance Criteria

**AP — flat budget + capped carryover (Logic):**
- **GIVEN** a player with `ap_leftover = 0`, **WHEN** their turn resets, **THEN** `current_ap = 10`.
- **GIVEN** `ap_leftover = 3`, **WHEN** reset, **THEN** `current_ap = 13`; **GIVEN** `ap_leftover = 5`,
  **THEN** 15; **GIVEN** `ap_leftover = 9`, **THEN** 15 (carry capped at 5, not 19).
- **GIVEN** `current_ap = 5`, **WHEN** `ap_spend(3)`, **THEN** true and `current_ap = 2`; **WHEN**
  `ap_spend(6)` from 5, **THEN** false and unchanged.
- **GIVEN** any pool, **WHEN** `ap_spend(0)`, **THEN** true and no change; **WHEN** `ap_spend(-1)`,
  **THEN** false and no change.
- **GIVEN** Player A active with `current_ap = 5` and inactive Player B with `current_ap = 10`, **WHEN**
  A `ap_spend(3)`, **THEN** A = 2 and B unchanged; **WHEN** `ap_spend(B, 1)`, **THEN** false, no change.
- **GIVEN** a player ends their turn with `current_ap = 7`, **WHEN** their next turn resets, **THEN**
  `current_ap = 10 + min(7, 5) = 15` (carryover applied, capped).

**Credits — banked income + spend (Logic):**
- **GIVEN** `n = 0`, **WHEN** `credit_income` is computed, **THEN** 10; **GIVEN** `n = 4`, **THEN** 18;
  **GIVEN** `n = 5`, **THEN** 19; **GIVEN** `n = 8`, **THEN** 22.
- **GIVEN** `current_credits = 6` and `credit_income = 10`, **WHEN** the turn resets, **THEN**
  `current_credits = 16` (income **added** to the banked balance, not reset).
- **GIVEN** a player banks Credits over two turns without spending (income 10 then 12), **WHEN** both
  resets have run, **THEN** `current_credits = 22` (accumulation; no cap, no discard).
- **GIVEN** `current_credits = 5`, **WHEN** `credits_spend(4)`, **THEN** true and `current_credits = 1`;
  **WHEN** `credits_spend(2)` from 1, **THEN** false and unchanged.
- **GIVEN** `has_economy_tech(player) = true` and `n = 4`, **WHEN** `credit_income` is computed, **THEN**
  22; **GIVEN** `has_economy_tech = false` and `n = 8`, **THEN** 22 (tech term contributes 0 when false).
- **GIVEN** `has_economy_tech = true`, `n = 6` vs `n = 7`, **WHEN** computed, **THEN** 26 and 27 (tech
  term capped at 6 — the 7th outpost's marginal drops back to +1).
- **GIVEN** `completed_outpost_count` returns negative, **WHEN** computed, **THEN** `n` clamps to 0 and
  income returns 10 (floor).

**Dual-cost logistics (Logic):**
- **GIVEN** a produce action costing (4 Credits, 1 AP), a player with `current_credits = 4` and
  `current_ap = 10`, **WHEN** applied, **THEN** true, `current_credits = 0`, `current_ap = 9`.
- **GIVEN** the same action, a player with `current_credits = 4` but `current_ap = 0`, **WHEN**
  attempted, **THEN** **false** and **neither pool changes** (AP surcharge unaffordable — both-or-nothing).
- **GIVEN** the same action, a player with `current_credits = 3` and `current_ap = 10`, **WHEN**
  attempted, **THEN** false and neither pool changes (Credits unaffordable).
- **GIVEN** a build action costing (9 Credits, 2 AP), a player with exactly `current_credits = 9` and
  `current_ap = 2`, **WHEN** applied, **THEN** true, both pools reach 0.
- **GIVEN** a cancelled under-construction Economy Outpost (build_cost 4, `CANCEL_REFUND_RATE` 0.5),
  **WHEN** cancelled, **THEN** `credits_credit(player, floor(4 × 0.5) = 2)` is applied and **no AP** is
  refunded.

**Cross-cutting (Logic):**
- **GIVEN** the same starting balances and the same ordered action sequence, **WHEN** applied twice,
  **THEN** the AP and Credit trajectories are identical (determinism).
- **GIVEN** an outpost built this turn (now under construction), **WHEN** `credit_income` is evaluated
  for this turn, **THEN** it is unchanged (completed-only); **WHEN** it completes and the owner next
  resets, **THEN** income includes its tiered bonus.

> **Test strategy (Logic — not blocked on undesigned dependencies).** Every AC is unit-testable now
> against stubs of `completed_outpost_count` and `has_economy_tech` the test controls, plus direct
> manipulation of `current_ap` / `current_credits` / `ap_leftover`. The dual-cost ACs need only a stub
> action carrying `(credit_cost, ap_cost)`. A later **integration** test (real Base & Production /
> Research completing structures and Economy Tech, observed at the next reset) is a separate,
> currently-tracked story.

**Experiential (advisory — vertical-slice playtest):**
- **GIVEN** the two-resource model at the shipped knobs (AP 10/carry 5; Credit income 10–32), **WHEN**
  a structured playtest is run, **THEN** players report that (a) the per-turn *tactical* budget still
  creates "not quite enough to do everything" pressure, and (b) the Credit war chest creates a
  satisfying *timing* decision (when to spend the pile) — **without** the old "I built something and now
  I can't act" frustration. This is the pivot's core felt goal and is the S4-05-style swing-back /
  tempo playtest's primary read.

## Open Questions

| Question | Owner | Notes / target |
|----------|-------|----------------|
| **Pillar 1 wording** — "One Economy, Every Choice" is literally contradicted by the two-resource split. Reword the pillar (e.g. "Every Choice Is a Tradeoff" across tempo + investment), or reinterpret it as owning only the Credit economy? | user / creative-director | **Design-direction call — flagged, not decided here.** The pivot preserves Pillar 1's *intent* (meaningful tradeoffs) but not its *letter*. Resolve in the pillars/vision doc as part of propagation. |
| **Flat AP / carryover / logistics-AP-cost tuning** — `FLAT_AP_PER_TURN` (10), `AP_CARRYOVER_CAP` (5), `PRODUCE_AP_COST` (1), `BUILD_AP_COST` (2), `RESEARCH_AP_COST` (base 1, per-tech overridable) are first-cut defaults. | game-designer + playtest | The most playtest-sensitive pivot numbers; tune against the S4-05 tempo playtest. Per-tech research surcharges let Research tune tempo cost tech-by-tech. |
| **Credit banking → snowball** — Credits now *accumulate* (unbounded stock), so a saved war chest enables larger single-turn bursts than the old use-it-or-lose-it pool. Does banking worsen the leader's snowball, and does the `BUILD_AP_COST` rate-limit sufficiently brake it? | economy-designer / game-designer | **Re-opened by the pivot.** The income *rate* is still capped (~26/~32), but stock is not. Consider a soft Credit cap or a stronger AP surcharge if playtest shows runaway bursts. |
| **Starting Credits** — does a player begin turn 1 with 0 Credits (earning their first income at their first reset) or a small starting balance so turn 1 isn't dead? | game-designer | Recommend: income applied at the first start-of-turn reset (turn 1 opens with ~10 Credits), no separate starting grant — mirrors the old model's turn-1 spendability. Confirm in playtest. |
| **AI two-currency scoring** — the AI scored everything in "value-per-AP"; with two currencies it needs a Credit↔AP conversion so a unified score still holds, and the lethal-floor-vs-economy-ceiling invariant must be re-validated. | ai-opponent.md (#11) | **Engineering, tracked in ai-opponent.md.** Anchor: Credit costs equal the old AP costs → ~1:1 conversion as a starting rate. |
| **Demand ≥ income ratio** — the "never quite enough" tension is now split: AP demand vs. the flat AP budget, and Credit demand vs. Credit income. Both need re-validation against action costs. | Movement/Combat (AP) + Base & Production/Research (Credits) + playtest | Carry a joint target into the cost-owning GDDs; re-validate whenever costs or the new knobs change. |
| Per-building/research **build times**, `completed_outpost_count` contract precision, determinism of downstream cost/count functions | Base & Production / Research | Unchanged from the single-pool design; carry forward. |
