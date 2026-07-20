# AP Economy

> **Status**: Approved 2026-07-19 (full `/design-review` — verdict NEEDS REVISION; 4 blocking items resolved same session and accepted)
> **Author**: user + main session (systems-designer + economy-designer consulted on formulas)
> **Last Updated**: 2026-07-19
> **Implements Pillar**: Pillar 1 (One Economy, Every Choice) — its home; Pillar 2 (Tempo Is the Skill)
> **Priority / Layer**: Vertical Slice / Foundation (system #3)

## Overview

AP Economy is the single per-turn action-point pool that pays for **everything** a player does —
moving, attacking, producing units, building outposts, and researching all draw from one budget.
At the start of a player's turn the pool is reset to their income (a frozen snapshot); any AP left
unspent at end of turn is lost (no banking). Income is a flat base plus a **diminishing** bonus for
each *completed* outpost the player controls, so a booming economy matures rather than snowballing
without limit. This system owns the income side and the spend framework; the individual action
costs live in the systems that charge them. It is the balance center of the whole game: the tension
between growing your economy, fielding an army, and teching up is *the* decision OVERCLOCK is built
around, and it all flows through this one pool.

## Player Fantasy

The player engages with the AP economy **directly, every single turn** — it is not background
infrastructure, it *is* the core decision. The fantasy is the satisfying pressure of **never quite
having enough**: each turn you have more things you want to do than AP to do them with, and choosing
*where* to invest — expand, fight, or tech — is the whole game. This is Pillar 1 (*One Economy,
Every Choice*) made felt: because there is exactly one currency, every spend is a real tradeoff, and
you feel your momentum compounding (or slipping) turn over turn (Pillar 2, *Tempo Is the Skill*). The
"spend it or lose it" rule keeps every turn live — you can't hoard your way to safety, you must
*commit*. When the economy is doing its job, the player feels like a commander making hard,
consequential calls under a budget, not a bookkeeper.

## Detailed Design

### Core Rules

1. **One pool per player.** At the start of a player's turn, their `current_ap` is reset to their
   `income` for that turn (a **frozen snapshot** — see Rule 5). At end of turn, any unspent AP is
   **discarded** (no banking) — formally, `current_ap := 0` for the player whose turn is ending, so
   no stale positive balance survives into the opponent's turn. *(The reset/discard **timing** is
   owned by Game State & Turn Manager via the registered `ap_reset_policy`; AP Economy owns the
   **amounts** and defines discard as the zero-assignment above.)*
2. **Everything spends from this one pool.** Move, attack, produce, build, research all call
   `spend()`. There is never a parallel resource that dodges the pool (Pillar 1 / anti-pillar).
3. **`can_afford(player, amount)` is a pure precondition query.** Every spender checks it *before*
   offering an action as legal (e.g. before the Command & Action Interface highlights a reachable
   tile or an affordable production option). It performs no deduction.
4. **`spend(player, amount)` is the sole mutator of the pool, and is atomic**: it validates
   (`player` is the active player, and `0 ≤ amount ≤ current_ap`), deducts the full amount, and
   returns success — or changes nothing and returns failure. **A spend against a non-active player's
   pool is rejected** — this is the enforcement point for Rule 7's "only the active player's pool is
   mutable" invariant, so a mis-scoped or out-of-turn caller can never move another player's AP. No
   partial spend. `spend(0)` is a no-op success (for the active player); a negative amount is
   rejected. AP Economy has **no** concept of "this unit already acted" — a unit may move *and*
   attack in one turn purely because AP allows it; the once-per-unit-per-turn attack flag is
   Combat's, not this system's.
5. **Income is a diminishing function of *completed* outposts, frozen at start-of-turn.** `income`
   is evaluated once, at that player's start-of-turn reset, and held fixed for their whole turn — it
   does **not** recompute mid-turn. Only **completed** outposts count (see Rule 6). *(Freezing the
   snapshot prevents an exploit: if income recomputed live, building an outpost mid-turn would refund
   AP the same turn and make your remaining AP depend on the order you acted in — a subtle
   non-determinism trap. Freezing keeps each turn's AP trajectory predictable from your action order
   alone.)*
6. **Under-construction outposts do not produce income.** Outposts (and research) have a **build
   time** (owned by Base & Production / Research) — they sit *under construction* for one or more
   turns before completing. Only outposts whose status is **completed** are counted by the income
   formula. An outpost destroyed while under construction never contributes income, and the AP spent
   on it is **not refunded** — that lost investment is the tactical punish for over-committing to a
   boom.
7. **Invariant:** `0 ≤ current_ap ≤ income_this_turn` at every observable point. `current_ap` only
   *decreases* (via `spend`) during the active player's turn and only *increases* at their own
   start-of-turn reset. It is never negative. Only the active player's pool is mutable at a time.
   **Enforcement (not just assertion):** non-negativity is guaranteed by the `n = max(0, …)` income
   clamp (the floor is `BASE_INCOME`) together with `spend`'s `amount ≤ current_ap` lower bound;
   single-player mutability is guaranteed by `spend`'s `player == active_player` gate plus the
   end-of-turn `current_ap := 0` discard. **Writer contract:** the stored `current_ap` (held on the
   game state) is written by exactly two paths — the start-of-turn **reset** (Game State & Turn
   Manager) and **`spend()`** (this system). Nothing else writes it directly; there is no bypass of
   `spend`'s validation.
8. **Deterministic.** Spends are sequential within the turn manager's single-action path; the same
   starting income and the same ordered action sequence always yield the same AP trajectory. No RNG.

### States and Transitions

The pool itself has no discrete state machine — it is an integer with the invariant above. Its
lifecycle across a turn:

| Moment | Effect on `current_ap` |
|--------|------------------------|
| Player's start-of-turn reset | `current_ap ← income(player)` (frozen snapshot for the turn) |
| Each `spend(amount)` during the turn | `current_ap ← current_ap − amount` (only on success; never below 0) |
| Player's end-of-turn | Unspent `current_ap` discarded — formally set to **0** (Rule 1); stays 0 until this player's next reset |
| Opponent's turn | This player's `current_ap` is 0 and immutable; only the active player's pool may be spent (Rule 7) |

### Interactions with Other Systems

| System | Data in | Data out | Interface owner |
|--------|---------|----------|-----------------|
| Game State & Turn Manager | calls reset (start) and `spend` (in apply_action step c); stores `current_ap` | — | Turn manager owns timing + storage; AP Economy provides `income()`/`spend()`/`can_afford()` |
| Base & Production *(undesigned)* | `completed_outpost_count(player)` (alive, owned, tagged outpost, **status = completed**); owns outpost build cost, **build time**, under-construction state | income reads the completed count only | Base & Production owns outposts; AP Economy reads the count |
| Research / Tech *(undesigned)* | owns research cost + build time + effect | `spend` for research cost | Research owns cost/effect; AP Economy provides the spend |
| Movement / Combat / Unit *(undesigned)* | each owns its own AP costs | `can_afford`/`spend` calls | those systems own their costs |
| Command & Action Interface / Game HUD *(undesigned)* | `current_ap`, `income`, `can_afford` per action | affordability drives which actions are offered/highlighted | those systems own presentation |

**Public interface:** `income(player) -> int` · `can_afford(player, amount) -> bool` ·
`spend(player, amount) -> bool`. (`current_ap(player)` read lives on the game state.)

## Formulas

### `ap_income(player)` — per-turn action-point income

`ap_income(player) = BASE_INCOME + OUTPOST_BONUS_TIER1 × min(n, TIER_THRESHOLD) + OUTPOST_BONUS_TIER2 × max(0, n − TIER_THRESHOLD)`

`where n = max(0, completed_outpost_count(player))`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `BASE_INCOME` | — | int const | 10 | Flat AP every player gets each turn regardless of board state |
| `OUTPOST_BONUS_TIER1` | — | int const | 2 | AP added per outpost for outposts 1–`TIER_THRESHOLD` (the full-bonus tier) |
| `OUTPOST_BONUS_TIER2` | — | int const | 1 | AP added per outpost beyond `TIER_THRESHOLD` (the diminished tier) |
| `TIER_THRESHOLD` | — | int const | 4 | Number of outposts that earn the full bonus before diminishing |
| `n` | `max(0, completed_outpost_count(player))` | int | 0 – (board-limited) | Count of the player's **completed, alive** outposts (HQ excluded; under-construction excluded), **clamped at 0** — a negative count from a buggy caller degrades to the floor rather than producing sub-floor/negative income (upholds Rule 7's non-negativity invariant) |
| `ap_income` | — | int | 10 – ~26+ | AP granted at the player's next start-of-turn reset |

> **Coefficients are the named tuning knobs, not literals.** The formula references `OUTPOST_BONUS_TIER1` (=2) and `OUTPOST_BONUS_TIER2` (=1) from the Tuning Knobs table — changing a knob changes the formula, with no second source of truth (data-driven-values coding standard).
> **`n` is clamped at 0.** `min`/`max` in the formula bracket the *sub-expressions relative to the threshold*, not `n` itself; the outer `max(0, …)` on `n` is what guarantees income can never fall below `BASE_INCOME`. Without it, a negative `completed_outpost_count` (e.g. a double-decrement bug in Base & Production) would silently produce income below 10 — and, below −5, a negative pool — violating Rule 7.

**Output range:** floor 10 (n = 0). Outposts 1–4 add +2 each; outposts 5+ add +1 each. Practically
tops out around ~26/turn (board build limits, not a hard formula cap).
**Worked examples:** n=0 → 10; n=2 → 14; n=4 → 18; n=5 → 19; n=8 → 22; n=12 → 26.

### `can_afford` / `spend` — the spend gate

```
# Pure query — no mutation, no active-player gate (safe to ask about any player, e.g. AI eval / HUD).
# Meaningful only for the active player, whose pool is the only spendable one.
can_afford(player, amount) = (amount >= 0) AND (amount <= current_ap(player))

# Sole mutator — atomic, and gated on active-player to enforce Rule 7.
spend(player, amount):
    if player != active_player(state):  return false      # only the active player's pool is mutable (Rule 7)
    if amount < 0:                      return false      # malformed, no change
    if amount == 0:                     return true       # no-op
    if amount > current_ap(player):     return false      # reject, no change
    current_ap(player) -= amount;       return true       # atomic deduction
```

> Income is a **start-of-turn frozen snapshot** — `income_this_turn` is the value returned at the
> most recent reset, held fixed for the whole turn. Individual **action costs** are **owned by their
> own GDDs**, not here — this formula section defines only the income side and the spend primitive.
> The values *(unit 2/4/5/7, attack 2, outpost 5, research 6, move per-tile 1/2/3)* are quoted here
> **illustratively and are non-authoritative** — the owning GDD (and, once populated, the entity
> registry) is the single source of truth. If a quoted number ever disagrees with its owning GDD,
> the owning GDD wins. *(Note: the Vertical-Slice roster is Scout 2 / Trooper 4 / Sniper 5 / Heavy 7
> — Heavy raised 6→7 in the 2026-07-20 unit-system design-review; the older "2/4/6" shorthand
> predates both the Sniper and that retune.)*

## Edge Cases

- **If a spend exceeds available AP**: `spend` returns false, `current_ap` unchanged (the spender
  should have gated on `can_afford` first; this is the defensive backstop).
- **If a player spends exactly all remaining AP**: allowed; `current_ap` becomes 0; further actions
  fail `can_afford` until the next reset. "Spend to zero" is normal, encouraged tempo play.
- **If an outpost is built this turn**: it enters *under construction* — income is **unchanged this
  turn** (frozen snapshot + completed-only rule). It contributes only after it **completes** and is
  then counted at a subsequent start-of-turn reset.
- **If a completed outpost is destroyed** (usually during the opponent's turn): the owner's frozen
  `income_this_turn` is unaffected; the loss is picked up at that owner's next start-of-turn reset.
- **If an under-construction outpost/research is destroyed**: it never produces income/effect and
  the AP spent on it is **not refunded** — the whole investment is lost (the boom punish).
- **If `n` crosses the tier boundary** (4 → 5): the 5th outpost adds only +1, not +2 (e.g. income
  goes 18 → 19, not 18 → 20).
- **If a player ends the turn with unspent AP**: it is **discarded**; the next turn starts at
  `income`, never `income + leftover` (no banking — Pillar 1).
- **If `spend(0)` is called**: no-op, returns true (defined for testability; no 0-cost action exists).
- **If a negative amount is passed to `spend`**: rejected, returns false, no change (guards against a
  malformed caller ever *increasing* AP).

## Dependencies

**Upstream (this system depends on):**

| System | Nature | Interface |
|--------|--------|-----------|
| Game State & Turn Manager | Hard | Stores `current_ap`; calls reset at start-of-turn and `spend` inside `apply_action`; honors `ap_reset_policy` |

**Downstream (systems that depend on this — all HARD):** Movement, Combat, Base & Production,
Research, Command & Action Interface, Game HUD, and the turn manager. Each, when authored, lists
AP Economy under its Dependencies.

**Provisional (undesigned dependencies):**
- **Base & Production** — must provide `completed_outpost_count(player)` (alive, owned, tagged
  outpost, status = completed, HQ excluded) and owns outpost build **cost**, **build time**, and the
  under-construction/destroyable state. If Base & Production later wants the HQ or in-progress
  outposts to count toward income, that conflicts with this GDD and must be reconciled.
- **Research / Tech** — owns research cost, build time, and effect; calls `spend` for the cost.

## Tuning Knobs

| Knob | VS Range | Default | Affects | If too high | If too low |
|------|----------|---------|---------|-------------|------------|
| `BASE_INCOME` | 6–14 | 10 | Baseline tempo; what you can do with zero economy | Rushing trivially strong; economy pointless | Every turn feels starved; game drags |
| `OUTPOST_BONUS_TIER1` | 1–3 | 2 (outposts 1–4) | Boom payoff / ROI (payback ≈ cost ÷ bonus) | Booming dominates; snowball | Booming never worth it |
| `OUTPOST_BONUS_TIER2` | 0–2 | 1 (outposts 5+) | Late-economy ceiling / snowball brake | Runaway leader (Pillar 2 risk) | Over-building pointless past 4 |
| `TIER_THRESHOLD` | 3–6 | 4 | Where diminishing returns kick in | Diminishing never bites → near-linear | Booming capped too early |
| No-banking rule | — | fixed | "Spend it or lose it" tempo | (not a knob — core Pillar 1 rule) | — |

> Action costs (unit/attack/outpost/research/move) are **not** knobs of this system — they live in
> their owning GDDs. `income` payback interacts with the outpost **build time** (owned by Base &
> Production): a longer build time lengthens effective payback and further brakes snowball.

## Visual/Audio Requirements

The economy is felt entirely through the HUD (specified as requirements; presentation owned by the
Game HUD / Command interface):
- **AP counter** prominently displayed, ideally with a start-of-turn "fill" flourish as the pool
  resets to income, and a visible tick-down on each spend — the player must always feel the budget.
- **Income breakdown** legible on demand (base + outpost contribution), so the player understands
  *why* their income is what it is.
- **Neon Retro-Future note:** AP feedback is one of the few things the visual anchor reserves neon
  for ("neon means this matters") — the AP counter and affordability highlights should read as
  first-class, high-saturation UI.
- Audio: a start-of-turn AP-fill cue and a per-spend tick (specs owned by the audio pass).

## UI Requirements

The HUD displays `current_ap` and `income`; the Command & Action Interface uses `can_afford` to
decide which actions are shown as available vs. greyed out (you should be able to *see* what you can
afford before committing — Pillar 3). Presentation and interaction are owned by those two GDDs (#9,
#10); this system owns the data and the affordability query.

> 📌 **UX Flag — AP Economy**: The AP counter, income breakdown, and affordability highlighting are
> central to readability. In Phase 4 (Pre-Production), run `/ux-design` for the core HUD **before**
> writing epics; stories should cite `design/ux/[screen].md`, not this GDD.

## Acceptance Criteria

- **GIVEN** `n = 0` completed outposts, **WHEN** income is computed, **THEN** it returns 10.
- **GIVEN** `n = 4`, **WHEN** income is computed, **THEN** it returns 18; **GIVEN** `n = 5`, **THEN**
  19 (the 5th outpost adds +1, not +2); **GIVEN** `n = 8`, **THEN** 22.
- **GIVEN** `current_ap = 5`, **WHEN** `spend(3)`, **THEN** it returns true and `current_ap = 2`;
  **WHEN** `spend(6)` from `current_ap = 5`, **THEN** it returns false and `current_ap` is unchanged.
- **GIVEN** any pool, **WHEN** `spend(0)`, **THEN** it returns true and nothing changes; **WHEN**
  `spend(-1)`, **THEN** it returns false and nothing changes.
- **GIVEN** an outpost is built this turn (now under construction), **WHEN** income is evaluated for
  the current turn, **THEN** it is unchanged (only completed outposts count).
- **GIVEN** an outpost completes before a player's reset, **WHEN** their start-of-turn income resets,
  **THEN** the new income includes that outpost's tiered bonus.
- **GIVEN** an under-construction outpost is destroyed, **WHEN** it dies, **THEN** no AP is refunded
  and it never contributes income.
- **GIVEN** a player ends the turn with 4 AP unspent, **WHEN** end-of-turn resolves, **THEN** those 4
  AP are discarded and the next turn begins at `income`, not `income + 4`.
- **GIVEN** the same `income_this_turn` and the same ordered action sequence, **WHEN** applied in two
  runs, **THEN** the resulting AP trajectories are identical (determinism).
- **GIVEN** `current_ap = 0`, **WHEN** `can_afford(player, amount)` is queried for any `amount > 0`,
  **THEN** it returns false and `current_ap` is unchanged (backend gate — AP-Economy-scoped).
  *(The UI-side "the action is not offered / is greyed out when `can_afford` is false" is a separate,
  currently-blocked AC owned by the Command & Action Interface GDD (#9), not this system.)*
- **GIVEN** `current_ap = 5`, **WHEN** `spend(5)` (spend to exactly zero), **THEN** it returns true,
  `current_ap = 0`, and a subsequent `can_afford(player, 1)` returns false.
- **GIVEN** Player A is active with `current_ap_A = 5` and Player B (inactive) has `current_ap_B = 10`,
  **WHEN** A calls `spend(A, 3)`, **THEN** `current_ap_A = 2` and `current_ap_B` is unchanged at 10;
  **WHEN** `spend(B, 1)` is attempted (B is not the active player), **THEN** it returns false and no
  pool changes (Rule 7 — only the active player's pool is mutable).
- **GIVEN** a player ends their turn with `current_ap = 4`, **WHEN** end-of-turn discard resolves,
  **THEN** `current_ap` is set to **0** (not merely "irrelevant"), and remains 0 through the
  opponent's turn until this player's next reset.
- **GIVEN** a player's `income_this_turn` was frozen at 18 (`n = 4`), and one of those 4 completed
  outposts is destroyed during the opponent's turn, **WHEN** `income_this_turn` is read again before
  this player's next reset, **THEN** it still returns 18; only at the player's **next** start-of-turn
  reset does income drop to 16 (`n = 3`). *(Mirror of the build-this-turn AC: frozen income is immune
  to same-turn increase **and** decrease.)*
- **GIVEN** `completed_outpost_count(player)` returns a negative value (defensive — a caller bug),
  **WHEN** income is computed, **THEN** `n` clamps to 0 and income returns the floor `BASE_INCOME`
  (10), never below; `current_ap` after reset is therefore never negative.
- **GIVEN** `current_ap = 5`, **WHEN** `can_afford(player, 3)` is queried, **THEN** it returns true
  and `current_ap` remains 5 (pure query, no mutation); **WHEN** `can_afford(player, -1)`, **THEN**
  false.
- **GIVEN** `n = 2` (interior of tier 1) and `n = 12` (deep in tier 2), **WHEN** income is computed,
  **THEN** it returns 14 and 26 respectively (matches the published worked examples).

> **Test strategy (Logic story — not blocked on undesigned dependencies).** Every AC above is
> unit-testable **now** against a **stub** of `completed_outpost_count(player)` that the test controls
> directly: set the stub to 4, trigger a reset (income = 18), flip the stub to 5 mid-"turn," and
> assert `income_this_turn` is still 18 until the next reset. No real Base & Production or Research
> implementation is required, so AP Economy's BLOCKING unit-test gate does **not** wait on #7/#8. A
> separate **integration** test (Base & Production genuinely completing/destroying an outpost and AP
> Economy observing the change at the next reset) is a distinct, currently-blocked story to track once
> Base & Production ships — do not gate this system's Definition-of-Done on it.

**Experiential (advisory — vertical-slice playtest, not unit-testable):**
- **GIVEN** the frozen income at each tier (10 / 14 / 18 / 22 / 26), **WHEN** a structured playtest is
  run, **THEN** players consistently report *wanting to do more each turn than their AP allows* (the
  "never quite enough" fantasy holds across the income range — not just at the low, prototype-validated
  tiers). *(This AC cannot be satisfied by this document alone: it depends on the demand side — action
  costs owned by Movement/Combat/Base & Production — and must be carried as a **joint** target across
  those GDDs and validated in the slice. See Open Questions.)*

## Open Questions

| Question | Owner | Notes / target |
|----------|-------|----------------|
| Exact per-building/research **build times** | Base & Production (#7) / Research (#8) | Decided: configurable per building; set concrete values there. Longer times = stronger snowball brake |
| Does tiered diminishing + build time sufficiently tame the 24×24 snowball, or is a further brake needed? | economy-designer / game-designer | Validate in the vertical slice; model showed ~26 ceiling with tiers |
| Should the income tiers/threshold be **faction-differentiated** (e.g. a boom faction scales better, a rush faction has a higher base)? | Faction Identity (#12) | Natural asymmetry lever; keep faction GDD shallow until the asymmetry prototype |
| Any refund on **voluntarily cancelling** one's own under-construction building (vs. it being destroyed)? | Base & Production (#7) | This GDD sets: no refund on *destruction*; voluntary-cancel policy is Base & Production's call |
| **Snowball / ROI / income ceiling** — outpost payback is fast (≈2.5 turns at tier 1) and flat-cost outposts get *relatively* cheaper as the leader grows; income has no formula cap. Is a hard outpost-slot cap, cost-scaling, or a comeback/rubber-band lever needed? | Base & Production (#7) + Game State (`MAX_ROUNDS`) | **Downstream (joint balance).** This GDD's only lever (tiered diminishing) is present; the acquisition-rate, hard cap, build-time, and rubber-band levers are not ours. Validate in the vertical slice. Base & Production **must** state a hard max outpost count so income has a real ceiling |
| **Demand ≥ income ratio** — "never quite enough" is a ratio of wants (costs) to budget (income); it cannot be verified from income alone. | Movement / Combat / Base & Production (joint) + playtest | **Joint acceptance criterion:** target demand ≥ ~1.15× income at every tier (10/14/18/22/26). Carry this AC into each cost-owning GDD; re-validate the income knobs whenever action costs change (they were tuned against provisional prototype costs) |
| ~~**Per-unit action/movement cap**~~ — **RESOLVED 2026-07-20 (unit-system design-review).** Decision: no *hard* cap; instead a per-unit **`soft_move_cap`** — tiles entered past the threshold cost escalating AP (`move_cost × SOFT_MOVE_PENALTY`), mirroring this GDD's tiered diminishing-returns shape. Kiting/rushing stays viable but is self-taxing. | Movement (#5) owns the escalation formula; Unit (#4) owns the threshold | **Closed.** Unit System (#4) sets the `soft_move_cap` values; **Movement GDD (#5) must be revised** to add the escalation curve. AP Economy still correctly owns no per-unit action limit (only the shared pool) |
| **Bimodal meta by map size** — global income constants make small maps (8×8) rush-favored and large maps (24×24) boom-favored; economy is turn-bound, rush is tile-bound. | game-designer / level design + playtest | **Downstream (playtest).** Either pin the VS to one map size or make rush timing / economy a function of board size before locking constants |
| **Determinism of downstream inputs** — the "same income + same ordered actions → identical trajectory" guarantee holds only if `completed_outpost_count` and every downstream cost function are pure (no RNG). | Movement / Combat / Base & Production / Research | Contract requirement on all cost-owning GDDs: no RNG in cost or count functions. Add to each system's Dependencies when authored |
| **`completed_outpost_count` contract precision** — needs a *functional* definition of "outpost" (not just a tag) and a stance on disabled/supply-cut but structurally-complete outposts, plus the ownership-sampling instant relative to reset (capture/recapture churn). | Base & Production (#7) | Pre-empt accidental contract violation once #7 is authored; "owned"/"completed" are already load-bearing vocabulary here |
