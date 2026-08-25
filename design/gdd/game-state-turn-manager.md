# Game State & Turn Manager

> **Status**: Designed — **In Revision (PIVOT 2026-08-05)** for the AP↔Credits split (see ap-economy.md).
> **Author**: user + main session
> **Last Updated**: 2026-08-05 (AP↔Credits pivot: start-of-turn step 4 splits into **reset AP to a flat
> value + capped carryover** and **add Credit income to the banked Credit pool**; end-of-turn no longer
> discards AP (it carries into the next reset, capped) and Credits are never discarded. Both resets still
> follow the build-timer advance, so a just-completed structure counts toward Credit income this
> turn. See ap-economy.md.)
> **Prior**: 2026-07-21 (Base & Production reconciliation: Core Rule 3's Start-of-turn phase became an
> explicit **canonical numbered sequence** — flags → start-of-turn effects (incl. build-timer advance)
> → income, in that order. `base-production.md` Rule 6 and AP Economy both cite it.)
> **Implements Pillar**: Pillar 2 (Tempo Is the Skill — deterministic, legible turn/state advancement); enables Pillar 3 (Readable Board)
> **Priority / Layer**: Vertical Slice / Foundation (system #2)

## Overview

Game State & Turn Manager is the authoritative, render-decoupled model of everything true
about a match — the grid, all entities (units and structures with their positions and health),
each player's per-turn state (current AP, banked Credits, income modifiers, researched tech, faction),
whose turn it is, the round number, and whether the match is still in progress or won — plus the
turn/phase loop that advances play and detects victory. Every other system reads from and
mutates this model through a single validated "apply action" path; the renderer and the AI are
pure *consumers* of it and never own authoritative data. Crucially, the state is a deterministic,
**clonable** data structure with no dependency on rendering, so the AI can simulate hypothetical
futures on a copy and the test suite can run the whole game headlessly. This is the spine of the
project: get it right and the AI, the tests, and every gameplay system have a clean foundation;
get it wrong and all three become expensive.

## Player Fantasy

Infrastructure — players never "use" the turn manager, they feel *what it guarantees*: the game
always knows exactly what is true, turns resolve cleanly and in a predictable order, and "it's my
turn / it's their turn" is never ambiguous. It serves Pillar 2 (*Tempo Is the Skill*) by making
state advancement fully deterministic — the player can trust that any outcome followed from their
choices and the rules, never from hidden state or a coin the game flipped behind the screen. When
the turn manager is doing its job, it is invisible; the player simply experiences a game that is
always fair, always legible, and always exactly where they left it.

## Detailed Rules

### Core Rules

1. **The game state is the single authoritative model.** It contains: the Grid (owned by Grid &
   Terrain, held here); the entity set (units + structures, each with owner, position, hp, and
   per-turn flags); per-player state (current AP, banked Credits, income modifiers, researched-tech
   flags, faction id); the `active_player`; the `round_number`; and the `match_status`.
2. **A match is an alternating sequence of turns.** In the 2-player Vertical Slice, turns alternate
   P1 → P2 → P1 …. Exactly one player is active at a time.
3. **Each turn runs three phases:**
   - **Start-of-turn** — the **canonical ordered sequence** this system owns (other systems contribute
     effects but do **not** define the order). Steps run in exactly this order:
     1. **Set the active player.**
     2. **Clear per-turn flags** for the active player's pieces — units (`has_attacked`, movement
        state) and structures (`units_produced_this_turn`, structure `has_attacked`). *(Unit System and
        Base & Production own the flag semantics; the turn manager owns when they clear.)*
     3. **Apply start-of-turn effects** — including **Base & Production's build-timer advance** (under-
        construction structures decrement; any reaching 0 transition to Completed) and Research's
        research-timer advance. These run **before** step 4 so a just-completed structure counts
        toward Credit income *this* turn.
     4. **Reset the two resources** (both amounts owned by AP & Credits Economy):
        - **4a. Reset AP to flat + capped carryover** — set `current_ap := FLAT_AP_PER_TURN +
          min(unspent_ap_from_last_turn, AP_CARRYOVER_CAP)`. AP does **not** depend on the economy.
        - **4b. Add Credit income to the banked pool** — `current_credits += credit_income`. Because this
          follows step 3, the income observes the freshly-completed structures. Credits **accumulate** —
          this is an add, not a reset.
     *(The reset/carry/bank **timing** is owned here; the resource **amounts** are owned by AP & Credits
     Economy. Base & Production's Rule 6 and AP & Credits Economy's start-of-turn behavior both cite this
     ordered sequence — it is the single source of truth for start-of-turn ordering.)*
   - **Action phase** — the active player (human or AI) issues AP- and/or Credit-costed actions via
     `apply_action` until they end the turn or have no meaningful action left.
   - **End-of-turn** — **no discard**: unspent AP carries into the player's next start-of-turn reset
     (capped at `AP_CARRYOVER_CAP`, step 4a) and banked Credits persist untouched. Pass control to the
     opponent. *(The old "discard unspent AP" rule is superseded by the AP↔Credits pivot; capped AP
     carryover replaces it, and Credits never discard.)*
4. **`round_number` increments** each time control returns to the starting player (i.e. after both
   players have taken a turn). The HUD may display it as "Round N".
5. **Victory is by HQ destruction.** After every state mutation that could destroy an HQ, a win-check
   runs; if a player's HQ reaches 0 hp, `match_status` becomes `GameOver(winner = opponent)` and no
   further turns or actions are accepted.
6. **All state transitions are deterministic.** Given the same initial state and the same ordered
   sequence of actions, the resulting state is identical every run. No RNG participates in turn or
   state advancement. (Map layout randomness is seeded and resolved once at map load by Grid & Terrain.)
7. **The state is render-decoupled and clonable.** The model can be instantiated, mutated, queried,
   and **deep-copied** with no rendering node present. `clone()` yields an independent state the AI
   can apply hypothetical actions to without affecting the authoritative game. The renderer observes
   change events and draws; it never holds source-of-truth data.
8. **All mutation flows through `apply_action(action)`**, which (a) validates legality (enough of the
   action's resource(s) — AP and/or Credits, legal target, correct active player), (b) applies the change
   atomically, (c) deducts the cost (AP for move/attack; Credits **and** the AP surcharge for
   produce/build/research — a both-or-neither commit), and (d) runs the win-check. **Illegal actions are
   rejected and leave the state — including both AP and Credits — unchanged.**

### States and Transitions (match state machine)

| State | Meaning | Transitions to |
|-------|---------|----------------|
| `Setup` | Map + entities initialized, `round_number = 1`, AP and Credits unset | → `PlayerTurn(starting)` on match start (fires Start-of-turn for the starting player) |
| `PlayerTurn(P)` | Player `P` is in the Action phase | → `EndTurn(P)` when P ends the turn or has no legal action; → `GameOver` if a win-check triggers mid-turn |
| `EndTurn(P)` | Cleanup: retain P's unspent AP as carryover (capped at the next reset) and P's banked Credits — no discard | → `PlayerTurn(other)` (runs Start-of-turn for the other player); increments `round_number` when P was the second mover |
| `GameOver(winner)` | Terminal | (none — no further input accepted) |

`active_player` toggles on every `EndTurn → PlayerTurn` transition. The turn loop can never
softlock: a player with zero legal actions may always end their turn (see Edge Cases).

### Interactions with Other Systems

| System | Data in | Data out | Interface owner |
|--------|---------|----------|-----------------|
| Grid & Terrain | grid model at match load | occupancy/terrain queries for all systems | Grid (held inside state) |
| AP & Credits Economy | `credit_income` amount, AP/Credit spend & can_afford requests | current AP + current Credits per player | Economy owns amounts (`credit_income()`/`ap_spend()`/`credits_spend()`/`*_can_afford()`); **turn manager owns the start-of-turn reset timing (AP flat+carry, Credit income add) and the no-discard carryover/bank at end-of-turn**, and stores `current_ap` + `current_credits` |
| Unit System | unit definitions | per-unit state storage; per-turn flag reset | shared (state stores, turn manager resets) |
| Base & Production, Combat, Research | apply-action mutations | updated entities/state; HQ-destroyed event → win-check | apply_action path (turn manager) |
| AI Opponent | `clone()` + read API | chosen action sequence (via apply_action) | turn manager (read + clone interface) |
| Command & Action Interface / HUD | read active_player, AP, round, entities, status | player actions via apply_action | turn manager (read + apply interface) |

**Public interface (the contract everything builds against):**
- Read (side-effect-free): `active_player`, `current_ap(player)`, `current_credits(player)`,
  `round_number`, `match_status`, `entities()`, `entity_at(tile)`, `grid`.
- Simulate: `clone() -> GameState` (deep copy for AI lookahead).
- Mutate: `apply_action(action) -> Result` (validate → apply → deduct cost (AP and/or Credits) → win-check; atomic).
- Control: `end_turn()`, `start_match(map, starting_player)`.

## Formulas

Game State & Turn Manager carries no *balance* formulas — its logic is a deterministic state
machine. The precise transition rules:

**Active-player toggle:**

`next_active(P) = the other player` (2-player duel; P1 ↔ P2)

**Round increment condition:**

`round_number += 1` iff the player who just ended their turn is the **second mover** of the round
(i.e. control is about to return to the starting player).

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| round_number | int | 1 … (MAX_ROUNDS or ∞) | Completed-round counter; both players act per round |
| active_player | enum | {P1, P2} | Whose turn it is |

**Terminal predicate:**

`is_terminal(state) = (state.match_status is GameOver)` — true once any HQ is destroyed, or when
`MAX_ROUNDS` is reached (if that optional knob is set). **Example:** starting player P1; after P1
then P2 both end their turns, `round_number` goes 1 → 2 and `active_player` returns to P1.

> Resource **amounts** (Credit income, spend costs, the flat-AP and carryover-cap constants) are owned
> by the AP & Credits Economy GDD. This system defines only *when* AP is reset (start-of-turn, flat +
> capped carryover) and *when* Credit income is added (start-of-turn, to the banked pool) — and that
> neither resource is discarded at end-of-turn (AP carries capped; Credits bank).

## Edge Cases

- **If the active player has zero legal actions at start of turn** (can't afford anything, no legal
  move): they may still `end_turn()` manually; if a UI auto-pass is offered, it simply ends the turn.
  **The loop never softlocks.**
- **If a player ends the turn with unspent AP**: it is **carried** into their next start-of-turn reset,
  capped at `AP_CARRYOVER_CAP` (superseding the old "discard" rule). Banked Credits persist untouched.
- **If an illegal action is applied** (insufficient AP or Credits, illegal target, wrong active player):
  it is **rejected**; the state, including AP, Credits, and entities, is unchanged; nothing is spent
  from either pool (dual-cost actions are both-or-neither).
- **If a win-condition is met mid-turn**: the match transitions to `GameOver` **immediately**;
  remaining AP/Credits and any queued actions are ignored; no further input is accepted.
- **If two HQs would be destroyed in the same resolution step** (not possible with Vertical-Slice
  single-target combat, but reserved for future AoE): the **non-active player wins** — an attacker
  cannot win by an action that also destroys their own HQ. Documented so a future AoE weapon can't
  create an undefined draw.
- **If the same action is submitted twice** (double-click / double-send): the second submission is
  re-validated against the now-updated state and is typically rejected (AP already spent / target
  gone); no double-apply is possible.
- **If `MAX_ROUNDS` is set and reached with no HQ destroyed**: the match ends by **tiebreak** (see
  Tuning Knobs) and transitions to `GameOver`. This is the anti-drag safety valve.
- **State must be fully serializable** (every field a plain, copyable value) even though save/load
  is deferred to the Persistence GDD (Alpha) — this is a design constraint on the model *now* so
  `clone()` and future save both work.

## Dependencies

**Upstream (this system depends on):**

| System | Nature | Interface |
|--------|--------|-----------|
| Grid & Terrain | Hard | Holds the grid model; uses its occupancy/terrain/`manhattan_distance` queries |

**Downstream (systems that depend on this — all HARD):** AP & Credits Economy, Unit System, Movement,
Combat Resolution, Base & Production, Research, AI Opponent, Command & Action Interface, Game HUD. Each,
when authored, must list Game State & Turn Manager under its own Dependencies.

**Faction Identity (#12)** is also a downstream dependent (Hard): Game State stores `faction_of(player)`
and applies each faction's `starting_loadout` at the Setup phase (faction is locked at the
Setup→PlayerTurn transition and immutable thereafter). This faction *plumbing* is the **only** faction
handoff a playable Neutral-vs-Neutral VS needs; the per-domain `effective_X` deltas are identity under
the Neutral default and land with the asymmetry prototype. *(Reciprocity closed 2026-07-22 via
`/review-all-gdds` C-5 — see faction-identity.md Dependencies.)*

**AP & Credits Economy interface (updated by the 2026-08-05 pivot):** the turn manager stores
`current_ap` + `current_credits` and invokes, at start-of-turn: (a) an **AP reset** to
`FLAT_AP_PER_TURN + min(unspent, AP_CARRYOVER_CAP)`, and (b) a **Credit income add**
(`current_credits += credit_income(player)`). During the Action phase it calls `ap_spend()` /
`credits_spend()` (and `*_can_afford()` for legality). At end-of-turn it neither discards AP (it carries,
capped) nor Credits (they bank). The Economy GDD owns those amounts/constants; the turn manager owns the
timing. *(Supersedes the pre-pivot `income()`/`spend()`/`ap_reset_policy` single-pool interface.)*

### ★ Reciprocal downstream — the wave-2 systems (added 2026-08-24, S6-09)

Cross-review **W-1**: the system below declares a dependency on this document, and this
document did not list it back. Reciprocity was **0/11 across the corpus** — every new GDD pointed
up, no old GDD pointed back, so reading only this file gave no hint that changing it would break
them. Restored mechanically; the relationship nature is copied from each new GDD's own
Dependencies table, which remains the authority.

| Downstream system | Nature |
|---|---|
| **Unit Upkeep (#15)** | Soft |

## Tuning Knobs

| Knob | VS Range | Default | Affects | If too high | If too low |
|------|----------|---------|---------|-------------|------------|
| `STARTING_PLAYER` | {P1, P2, map-defined} | map-defined | Who moves first (first-move advantage) | — | — (see Open Questions on first-player advantage) |
| `MAX_ROUNDS` (optional) | off, or 20–100 | off (VS default) | Hard round cap → forces resolution; **anti-drag lever** | Games can still drag toward the cap | Games cut off before natural resolution feels satisfying |
| `TIEBREAK_METRIC` (used iff `MAX_ROUNDS` set) | {total HQ hp, tiles controlled, unit count} | total HQ hp | How a capped game is decided | — | — |

> **Implementation status, 2026-08-21.** `total HQ hp` is implemented and **is** the default, matching this row. It was not, for a period: only `unit count` shipped (HQ hp needed schema fields that had not landed yet), it became the de-facto default, and it was implemented as a count of *every entity* — structures and the HQ included — so a capped game was decided by who had built more. Corrected once `MAX_ROUNDS` was armed for the vertical slice and the behaviour became reachable. `tiles controlled` is **still unimplemented**: nothing in the corpus defines what "controlled" means for a tile, and picking a definition is a design decision rather than a gap to fill. ★ Note that two untouched HQs are an exact tie, which falls through to the non-active-player rule — so this metric only discriminates once someone has actually damaged an HQ.
| Win condition set | {HQ destruction} (+ optional MAX_ROUNDS tiebreak) | HQ destruction | Victory definition | — | Objective-based conditions are Alpha+ |

> **`MAX_ROUNDS` + `TIEBREAK_METRIC` is a direct lever on the endgame closeout-drag problem** — a
> decided-but-dragging game ends at the cap and is scored by the tiebreak. Coordinate the exact
> approach with the Base & Production GDD (which owns the drag problem) and the concept's Design
> Risks; this is one candidate solution among several (production caps, forward deploy, attrition).

## Visual/Audio Requirements

Foundation infrastructure — minimal intrinsic visuals, but the turn manager's *events* drive key
feedback (owned mostly by the HUD / Command interface, specified here as requirements):
- **Turn-change feedback:** a clear "YOUR TURN / ENEMY TURN" banner on every `PlayerTurn`
  transition — the player must never be unsure whose turn it is (Pillar 3).
- **Victory / defeat presentation** on `GameOver`, stating the winner.
- **Start-of-turn reset moment** is a natural beat for two small flourishes: the AP pool filling to its
  flat value (+ any carryover) and the Credit balance ticking up by its income.
- Audio: a turn-change stinger and a victory/defeat cue (specs owned by the audio pass, not this GDD).

## UI Requirements

The turn manager exposes `active_player`, `round_number`, `match_status`, and per-player `current_ap`
and `current_credits` for the HUD to display, plus the **End Turn** control and the turn/victory
banners. The *visual
design and interaction* of these live in the Game HUD (#10) and Command & Action Interface (#9) GDDs,
not here — this system owns the data and events, not their presentation.

> 📌 **UX Flag — Game State & Turn Manager**: This system drives the turn indicator, End Turn control,
> and victory/defeat screens. In Phase 4 (Pre-Production), run `/ux-design` for the core HUD **before**
> writing epics; stories should cite `design/ux/[screen].md`, not this GDD.

## Acceptance Criteria

- **GIVEN** a new match, **WHEN** it starts, **THEN** `active_player` = the starting player,
  `round_number` = 1, `match_status` = in-progress, the starting player's AP = `FLAT_AP_PER_TURN` (10),
  and their Credits = `credit_income` (the first income, added at the opening reset).
- **GIVEN** the active player ends their turn with unspent AP, **WHEN** End-of-turn resolves, **THEN**
  that AP is **retained as carryover** (not discarded) and their Credits persist, `active_player`
  switches to the opponent, and the opponent's AP resets to `FLAT_AP_PER_TURN + min(their_carry,
  AP_CARRYOVER_CAP)` while their Credits increase by `credit_income`.
- **GIVEN** both players have taken a turn in a round, **WHEN** the second player's turn ends,
  **THEN** `round_number` increments by exactly 1.
- **GIVEN** an HQ reaches 0 hp, **WHEN** the win-check runs, **THEN** `match_status` becomes
  `GameOver(winner = opponent)` and any subsequent `apply_action` is rejected.
- **GIVEN** an action costing more AP or Credits than the active player has, **WHEN** `apply_action` is
  called, **THEN** it returns failure and the state (AP, Credits, and entities) is unchanged; a dual-cost
  action short on either pool spends nothing from either.
- **GIVEN** the same initial state and the same ordered action sequence, **WHEN** applied in two
  separate runs, **THEN** the two resulting states are identical (determinism).
- **GIVEN** a headless instantiation with no rendering node, **WHEN** actions are applied and the
  state queried, **THEN** all reads and mutations function correctly.
- **GIVEN** the AI calls `clone()` and applies a hypothetical action to the clone, **WHEN** it does
  so, **THEN** the authoritative state is unchanged and the clone reflects the hypothetical.
- **GIVEN** the active player has zero legal actions at start of turn, **WHEN** the turn begins,
  **THEN** they can still `end_turn()` (no softlock).
- **GIVEN** `MAX_ROUNDS` is set and reached with no HQ destroyed, **WHEN** the cap is hit, **THEN**
  the `TIEBREAK_METRIC` decides the winner and `match_status` → `GameOver`.

## Open Questions

| Question | Owner | Notes / target |
|----------|-------|----------------|
| First-player advantage: does moving first confer an edge in a symmetric duel, and how to mitigate (fixed vs alternating start, or a compensation)? | game-designer / balance | Watch in vertical-slice playtests; faction asymmetry may absorb it |
| Is `MAX_ROUNDS` + tiebreak the right closeout-drag lever, or does a hard cap feel arbitrary? | game-designer (with Base & Production) | Decide alongside #7's drag solution; may combine with production caps |
| Exact serialization format for the state model? | Persistence & Campaign GDD (Alpha) | Design the model serializable now; format decided later |
| Should simultaneous HQ destruction ever be reachable (future AoE)? | Combat GDD author | VS single-target combat makes it impossible; rule reserved for Alpha |
| Is the state model an Autoload, a passed object, or an event-bus core? | → ADR (architecture phase) | Implementation choice — belongs in an ADR, not this GDD |
