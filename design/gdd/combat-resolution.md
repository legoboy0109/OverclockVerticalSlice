# Combat Resolution

> **Status**: Approved (independent `/design-review` 2026-07-21 — 4 blocking items fixed in-file; verdict NEEDS REVISION → accepted after revision). **Ranged model + Sniper/kiting balance remain spike-gated (unvalidated — prototype was pure melee); counterattack / defense / area-fire ship as OFF-by-default infrastructure.**
> **Author**: user + main session (systems-designer on damage formula; qa-lead on acceptance criteria; art-director on visual/audio)
> **Last Updated**: 2026-07-21 (independent `/design-review` revision — 4 blocking items fixed in-file: **structures are cover-immune** (Rule 6 — closes the HQ `defense 2` + `COVER_DR 1` = 3 floor-lock trap by rule, superseding the unenforced "keep structures off Cover" caveat; synced to base-production.md + registry); determinism AC rewritten to a defined state-equality predicate (no "byte-identical"); added missing ACs (structure cover-immunity, attacker-on-Cover, `preview_damage` guarantee, same-attack idempotency, AREA ring exact-boundary + `min_range ≤ attack_range` invariant, structure-as-attacker); fixed the "structures never counter" contradiction (Defensive Structure exception). Earlier 2026-07-21: reconciled with Base & Production #7 — `attack()` accepts a structure as attacker; the Defensive Structure, first `can_counterattack=true` entity, fires at Base-&-Production-owned `DEFENSIVE_ATTACK_COST`. No change to the damage-formula math.)
> **Implements Pillar**: Pillar 2 (Tempo Is the Skill — deterministic, no-RNG resolution so outcomes reward planning, not luck); Pillar 3 (Readable Board — targets and damage knowable before commit); Pillar 1 (attacks spend AP — the tactical budget; unchanged by the 2026-08-05 two-budget pivot, which moved only build/produce/research onto Credits)
> **Creative Director Review (CD-GDD-ALIGN)**: SKIPPED — Lean review mode (not a phase gate). Review pillar alignment manually or in the independent `/design-review`.
> **Priority / Layer**: Vertical Slice / Core (system #6)

## Overview

Combat Resolution is OVERCLOCK's deterministic damage-and-elimination engine: it resolves every
attack a unit makes and removes units whose hp reaches 0, with **no randomness anywhere in the
pipeline**. It supports two targeting profiles — **direct fire** (target the nearest enemy along a
cardinal line within range, the default for the whole Vertical-Slice roster) and an optional
**area/indirect** profile (a circular footprint bounded by a minimum and maximum range, for future
artillery-style units) — and a damage model that subtracts terrain **cover** and a per-unit
**defense** value before enforcing a minimum-1 floor. A **counterattack** step exists in the pipeline
but fires only when the struck unit's type has the `can_counterattack` flag set — a **per-unit-type
trait that is off for every Vertical-Slice unit by default** — so by default an attack is
one-directional and first-strike positioning is decisive, while a specific future unit can be given
retaliation without changing the rule for everyone. Players interact with combat directly and
constantly: every attack is a chosen action (spend `attack_cost` AP, pick a target) whose outcome is
fully knowable *before* it's committed, because the math has no dice in it. The system exists because
Pillar 2 (*Tempo Is the Skill*) demands that outcomes reward planning, not luck. It is also where
every other system's investment cashes out — the AP spent building, moving, and positioning a unit
only pays off in what that unit can do here. *(The `can_counterattack` and `defense` values and the
area-profile stat fields are Unit-owned and enter as infrastructure now — every VS unit ships with
`defense = 0`, `can_counterattack = false`, and direct-fire targeting; Combat owns the resolution and
formulas that consume them.)*

## Player Fantasy

Combat is where the player's planning pays off, and the fantasy is the **satisfaction of a calculated
kill** — you line up a shot, you already know it lands and exactly how much it takes off, and it
does. There is never a "should have hit but the dice said no" moment, because there are no dice. The
feeling OVERCLOCK is chasing here is the *Into the Breach* clarity: combat is a **solvable puzzle
with perfect information**, so a win feels earned by reading the board correctly and a loss teaches
you what you misread — never robs you. Landing a first strike that a well-positioned unit couldn't
answer, threading a Sniper's reach to hit something that can't hit back, spending your last AP on the
attack that caves an HQ — these are the beats. The emotional target is **control**: the player is a
commander whose decisions are the only thing that determines the outcome. This directly serves
Pillar 2 (*Tempo Is the Skill*) — "Depth comes from timing and sequencing, not from bigger
numbers... results must be predictable so mastery is about planning, not luck" — and Pillar 3
(*Readable Board, Deep Decisions*), since the shot and its damage are legible before you commit.
Combat should feel sharp and consequential, never swingy.

> `creative-director` not consulted — Lean review mode (specialist consultation reserved for
> HIGH-risk sections). Review this framing manually before production.

## Detailed Design

### Core Rules

1. **An attack is an AP-costed action.** A unit attacks by spending `attack_cost` AP (**Combat-owned**;
   default **2 AP** — see Tuning Knobs) and choosing a legal target. *(A **structure** attacker — the
   Base & Production Defensive Structure — instead spends its own **`DEFENSIVE_ATTACK_COST`** (1 AP,
   Base-&-Production-owned, deliberately below the unit rate); Combat's flat `attack_cost` is
   units-only. Everything else about resolution is identical.)* Attacks route through the Turn
   Manager's `apply_action` path (validate → apply → deduct AP → win-check), so an illegal or
   unaffordable attack is rejected atomically with no AP spent and no state change.
2. **Attack is once per unit per turn.** Legality is gated by Unit System's `can_attack(unit)`
   (returns `not has_attacked`). On a successful attack, Combat sets the attacker's
   `has_attacked = true` (Unit owns the flag; `reset_turn_flags()` clears it at the owner's
   start-of-turn). A unit **may move and attack the same turn** in either order — movement is never
   gated by `has_attacked`, and attacking never sets movement state.
3. **A target must be an enemy.** Combat never targets a unit or structure the attacker owns. Valid
   targets are enemy **units** and enemy **structures** (HQ, outposts — hp owned by Base &
   Production). Friendly pieces are never targets; in direct fire a friendly piece only ever *blocks*
   (Rule 4).
4. **Targeting profile — DIRECT (default, whole VS roster).** The attacker picks one of the 4 cardinal
   directions (per `grid_adjacency_mode`). Combat walks tiles outward from the attacker, tile by tile,
   up to the unit's `attack_range` (its maximum reach). The **first occupied tile or Impassable tile
   encountered stops the walk** (line of fire is blocked by *any* occupant — friendly or enemy — and
   by Impassable terrain). If that first blocker is an **enemy within `attack_range`**, it is the
   (only) legal target in that direction; otherwise there is no target that direction. **Nearest-only:
   no pierce, no shoot-through.** Direct-fire range is `[1, attack_range]` — it can strike an adjacent
   enemy. Range here is **cardinal-line distance** (steps along the straight line), which coincides
   with `manhattan_distance` only because the line is straight — a future non-cardinal profile must
   not assume the two are interchangeable.
5. **Targeting profile — AREA / INDIRECT (optional; no VS unit uses it by default).** For a unit whose
   `targeting_mode = AREA`, any tile within the range ring
   `min_range ≤ manhattan_distance(attacker, tile) ≤ attack_range` is targetable if it holds an enemy.
   This is a **circular (diamond, in the manhattan metric) footprint with a dead zone** inside
   `min_range` — the artillery gap: the unit cannot fire at things too close. **Indirect fire ignores
   line-of-fire blocking** — intervening units and Impassable terrain do *not* block an area shot (it
   arcs over). It remains **single-target**: exactly one enemy on one chosen tile within the ring
   takes damage (no splash/AoE in the VS — see Open Questions).
6. **Damage is deterministic, with cover and defense mitigation and a min-1 floor.** A hit deals
   `damage = max(MIN_DAMAGE, effective_attack(attacker) − cover_reduction(defender) − defense(defender))`,
   where `MIN_DAMAGE = 1` (a landed hit always removes at least 1 hp), `effective_attack` is
   Unit-owned (base attack + research bonus), `cover_reduction` is `COVER_DR` if the defender is a
   **unit** occupying a Cover tile else 0 (**Combat owns `COVER_DR`**; default **1**), and `defense` is
   the defender's `defense` stat (Unit-owned for units, Base-&-Production-owned for structures; default
   **0** for all VS units). **Structures are cover-immune** — a structure defender (HQ / outpost /
   Defensive Structure) *never* gains `cover_reduction` regardless of the tile it stands on; it
   mitigates only through its own `defense` stat. Cover is a positioning reward for mobile units that
   chose to stand there, not a bonus an immobile structure backs into. This keeps structure durability
   fully described by `hp + defense` alone and closes the `defense + COVER_DR` floor-lock trap for
   structures (see the Defense-stacking constraint in Formulas). Full formula in Formulas. No RNG.
7. **Counterattack (per-unit-type trait, off by default).** After the attacker's damage is applied and
   death/removal is resolved (Rule 8), a **single** retaliation fires **iff** the defender is still
   alive (`current_hp > 0`) **AND** the defender's type has `can_counterattack = true` **AND** the
   attacker is a legal target for the defender under the defender's own targeting profile and range (a
   melee defender struck from range 3 cannot counter; an AREA defender counters only if the attacker
   sits within its ring). The counter deals the defender's own `damage` (Rule 6, roles swapped) to the
   attacker. The counter is **free** (costs no AP, does not set the defender's `has_attacked`) and
   **never chains** — a counter cannot itself be countered. "No chain" is **structural**: the pipeline
   runs at most one conditional counter step per `apply_action` (step 6), non-recursively — it is not
   a runtime guard flag. The "legal target under the defender's own profile" check uses the
   defender's *full* targeting profile: a DIRECT counterer applies the cardinal-line/first-blocker
   rule (the attacker must be its nearest blocker in a cardinal direction within range); an AREA
   counterer applies its own `[min_range, attack_range]` ring and ignores line of fire, exactly as its
   primary attack would. **Every VS unit ships with `can_counterattack = false`, so no counters occur
   by default** (this overrides the concept prototype's "free counters" baseline). Dead defenders
   never counter.
8. **Death and removal are immediate.** When any piece's `current_hp` reaches 0 (from a primary hit or
   a counter), it transitions to Destroyed and is removed from Grid occupancy **in the same resolution
   step**; its tile becomes empty at once. The primary damage resolves before the counter, so a
   defender killed by the primary hit never retaliates. *(Cross-doc note, added 2026-07-22
   `/review-all-gdds`: this single-step, no-partial-application transition is what Research/Tech's
   Lab-destruction rule relies on to revert an in-progress tech to Not Started — Research adds a state
   check on top of this same `apply_action` step rather than a separate hook; see `research-tech.md`
   Core Rule 6.)*
9. **HQ destruction ends the match.** An HQ is a targetable enemy structure; when its hp reaches 0, the
   Turn Manager's win-check (which Combat's resolution triggers via `apply_action`) sets
   `GameOver(winner = opponent)`. Combat deals the damage; the Turn Manager owns the win rule
   (`win_condition`). **Simultaneous destruction of both HQs is out of scope for the VS** —
   single-target combat makes it impossible; the Turn Manager owns the reserved "non-active player
   wins" tiebreak for any future AoE that could reach two HQs in one step.
10. **Fully deterministic and headless.** Targeting, damage, counters, and removal are pure functions
    of the game state and the chosen action — stable iteration order, no RNG, computable on a
    `clone()` for AI look-ahead and headless tests.

### States and Transitions

Combat has no persistent state machine; a single attack is an **atomic ordered pipeline** applied
through `apply_action`:

| Step | Effect |
|------|--------|
| 1. Attacker selected | Combat computes the legal target set (per profile, Rule 4/5) for preview |
| 2. Target chosen | Validate: `can_attack(attacker)` true, `ap_can_afford(attack_cost)` true, target is a legal enemy in range/LoF |
| 3. Commit | `ap_spend(attack_cost)`; set attacker `has_attacked = true` (atomic; on any validation failure nothing changes) |
| 4. Primary damage | Compute `damage` (Rule 6); subtract from defender `current_hp` |
| 5. Primary death check | If defender `current_hp ≤ 0`: destroy + remove from Grid this step |
| 6. Counter (conditional) | If defender alive **and** `can_counterattack` **and** attacker in defender's range/profile: apply defender's `damage` to attacker (free) |
| 7. Counter death check | If attacker `current_hp ≤ 0` (from counter): destroy + remove this step |
| 8. Win-check | If any HQ reached 0 hp in steps 4–7: `match_status → GameOver` (Turn Manager) |

The pipeline is all-or-nothing: an attack that fails validation at step 2 spends no AP and mutates
nothing.

### Interactions with Other Systems

| System | Data in | Data out | Interface owner |
|--------|---------|----------|-----------------|
| Unit System | `effective_attack`, `attack_range` (=max range), `min_range`, `targeting_mode`, `defense`, `can_counterattack`, `can_attack()` | sets `has_attacked`; writes `current_hp` (via Unit's hp mutator); destroyed flag | **Unit owns all these stat fields + `can_attack()`/hp mutator; Combat owns the targeting rule, damage formula, counter rule, `attack_cost`, `COVER_DR`** |
| Grid & Terrain | `occupant_at`, `is_cover`, `manhattan_distance`, `neighbors`; `remove` on death | — | Grid (query + mutation API) |
| AP & Credits Economy | `ap_can_afford(attack_cost)` / `ap_spend(attack_cost)` | — | AP & Credits Economy owns the pools; Combat owns `attack_cost` |
| Game State & Turn Manager | attack applied via `apply_action`; runs win-check after resolution | updated entities; HQ-destroyed → GameOver | Turn Manager (mutation path + win rule) |
| Base & Production | structure `hp`/`defense` (HQ/outposts) as targetable enemies; the **Defensive Structure as an attacker** (`attack`/`attack_range`/`can_counterattack`, fired at `DEFENSIVE_ATTACK_COST`) | destroyed structure; damage/counter applied to targets | Base & Production owns structure stats + `DEFENSIVE_ATTACK_COST`; Combat owns targeting/damage/counter resolution (its `attack()` accepts a structure as attacker) |
| Research / Tech | attack buff already folded into `effective_attack` (read via Unit) | — | Research owns the bonus magnitude |
| Command & Action Interface / HUD | legal target set, damage preview, blocked-shot reason (blocked-by-friendly vs out-of-range vs dead-zone), **hypothetical-tile legal target set** (`legal_targets(unit, from_tile)`) for the after-move attack preview | display before commit | those systems own presentation |

**Public interface:** `legal_targets(unit) -> set<target>` (side-effect-free; respects profile, range,
LoF) · **`legal_targets(unit, from_tile) -> set<target>`** (side-effect-free overload — the targets `unit` could legally attack *as if it stood on `from_tile`*, evaluating range/LoF/profile from that hypothetical origin without moving the unit; see below) · `attack(attacker, target) -> Result` (validates → spends → applies damage → resolves
counter/death → win-check; atomic) · `preview_damage(attacker, target) -> int` (pure; the exact
damage `attack` will deal, for the pre-commit UI).

**Cross-system flag (owed by Command & Action Interface #9's `/design-review` 2026-07-22 — propagated here):** the **`legal_targets(unit, from_tile)` hypothetical-tile overload** is a *new Combat contract* introduced to back #9's honest "can attack after moving here" preview (D-3). It must be **pure/side-effect-free** (moves nothing, mutates no state) and evaluate targeting from `from_tile` exactly as the zero-arg form does from the unit's current tile. Called once per Move-preview entry across the reachable frontier, so its cost is `reachable`-sized — the AI-lookahead perf budget and the final signature are owed to `/create-architecture`. An optional future extension `preview_damage(attacker, target, from_tile)` would upgrade #9's binary marker to an after-move damage readout (not in current VS scope).

**Cross-system flag (owed to Unit System #4, Approved):** the fields `targeting_mode` (enum {DIRECT,
AREA}, default DIRECT), `min_range` (int, default 1), `defense` (int, default 0), and
`can_counterattack` (bool, default false) are **new Unit-owned stat fields** this GDD introduces.
`attack_range` (existing) serves as the **maximum** range for both profiles. Unit System's stat schema
and the entity registry must add these fields; Combat owns only the formulas/resolution that read
them. Logged as a handoff for Phase 5.

## Formulas

### `damage(attacker, defender)` — the one combat formula

`damage = max(MIN_DAMAGE, effective_attack(attacker) − cover_reduction(defender) − defense(defender))`

where `cover_reduction(defender) = COVER_DR if defender is a **unit** on an is_cover tile, else 0`.
**Structures are cover-immune** — `cover_reduction` is always 0 for a structure defender (HQ /
outpost / Defensive Structure), whatever tile it occupies.

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| `effective_attack(attacker)` | — | int | 2–7 | Attacker's attack after research (Unit-owned; base 2/3/5/6 + `RESEARCH_ATK_BONUS`) |
| `cover_reduction(defender)` | — | int | {0, `COVER_DR`} | Flat reduction if the defender is a **unit** on a Grid `is_cover` tile; **always 0 for a structure defender** (structures are cover-immune) |
| `COVER_DR` | — | int const | 0–2 (default **1**) | **Combat-owned** magnitude of Cover's damage reduction |
| `defense(defender)` | — | int | ≥0 (default **0**, all VS units) | **Unit- and structure-owned** per-unit flat mitigation. 0 on all VS units (infrastructure); populated on structures by Base & Production (HQ 2, Defensive Structure 1) |
| `MIN_DAMAGE` | — | int const | **1** (fixed) | Floor — a landed hit always removes ≥1 hp |
| `damage` | — | int | **1–7** (VS) | hp removed from the defender this attack |

**Output range:** floored at **1** (every connecting attack progresses the fight — nothing is a
no-op); practical ceiling **7** (researched Sniper). The subtractors only reduce, never raise, damage,
so no upper clamp is needed — a future higher-attack unit lifts the ceiling with no formula change.
**Counterattacks use this same formula with attacker/defender swapped.**

**Worked examples:**
- Scout → Trooper, Plain, unresearched: `max(1, 2 − 0 − 0) = 2`.
- Heavy → Sniper, Plain: `max(1, 5 − 0 − 0) = 5` (one-shots the 3-hp Sniper).
- Trooper → Heavy on Cover: `max(1, 3 − 1 − 0) = 2`.
- Floor case (future unit, `defense 2`, on Cover, researched Scout attack 3):
  `max(1, 3 − 1 − 2) = max(1, 0) = 1` — the floor rescues an otherwise-zero hit.

**Shots-to-kill matrix** (`ceil(hp / damage)`, `defense = 0`, unresearched) — the balance-legibility
check:

*On Plain:*

| Attacker ↓ / Defender → | Scout (3) | Trooper (6) | Heavy (10) | Sniper (3) |
|---|---|---|---|---|
| Scout (2) | 2 | 3 | 5 | 2 |
| Trooper (3) | 1 | 2 | 4 | 1 |
| Heavy (5) | 1 | 2 | 2 | 1 |
| Sniper (6) | 1 | 1 | 2 | 1 |

*On Cover (`COVER_DR = 1`):*

| Attacker ↓ / Defender → | Scout (3) | Trooper (6) | Heavy (10) | Sniper (3) |
|---|---|---|---|---|
| Scout (dmg 1) | 3 | 6 | 10 | 3 |
| Trooper (dmg 2) | 2 | 3 | 5 | 2 |
| Heavy (dmg 4) | 1 | 2 | 3 | 1 |
| Sniper (dmg 5) | 1 | 2 | 2 | 1 |

The matrix is monotonic — Cover never lowers time-to-kill, and a stronger attacker never needs more
shots than a weaker one against the same target. Cover roughly doubles a Scout's time-to-kill (an
intuitive player rule of thumb).

### `attack_cost` — AP to attack

Flat **2 AP** per attack, all unit types (Combat-owned). At floor income (10 AP) a player can
interleave up to 5 attacks, or trade them against moving/producing — the intended one-pool tension.
Deliberately **not** differentiated per unit: unit identity already lives in attack/range/hp, and Unit
System's per-AP audit assumes a constant 2-AP attack denominator. *(This flat cost is **units-only**;
the Base & Production Defensive Structure attacks at its own **`DEFENSIVE_ATTACK_COST`** = 1 AP — a
Base-&-Production-owned value below this rate, its reward for immobility. Counters are free for both.)*

> **Defense-stacking design constraint (handed to future defensive-unit designers):** keep a **unit's**
> `defense + COVER_DR < ` the roster's lowest `effective_attack` (currently 2, or 3 researched). Past
> that point an attacker's damage floor-locks at 1 regardless of its attack stat — correct (nothing is
> unkillable) but illegible (the player can't read *how close* they are to breaking through). Not a VS
> issue at the unit level (`defense = 0` on every VS unit); it first bites when Research's **Defense
> Tech** (`DEFENSE_TECH_BONUS = 1`) puts a unit on Cover at 2 mitigation — a guardrail for that case and
> for future defensive units. **Structures are exempt by construction:** because structures are
> cover-immune (Rule 6), a structure's mitigation is exactly its `defense`, never `defense + COVER_DR`,
> so the HQ (`defense 2`) can never stack to 3-with-Cover and floor-lock low-attack attackers. This is
> the resolution of the earlier "keep structures off Cover" guidance — it is now enforced by the
> cover-immunity rule, not by an unenforced placement assumption.

> **Sniper note (spike-gated, unchanged):** the damage formula has **no** attacker-range term, so it
> applies zero counter-pressure to a Sniper firing from range 3. With `can_counterattack = false` on
> every VS unit, nothing in Combat's own math punishes a kiting Sniper — consistent with (and not a
> fix for) the named no-counter spike hypothesis in Unit System. A damage-side lever, if the spike
> wants one, is `COVER_DR` (roster-wide) or a future unit `defense`, not `attack_cost`.

## Edge Cases

- **If mitigation would reduce damage to 0 or below** (`cover_reduction + defense ≥ effective_attack`):
  damage clamps to `MIN_DAMAGE` (1). A connecting attack is never a no-op; nothing on the board is
  ever unkillable.
- **If the defender is killed by the primary hit**: it is removed that step and **does not
  counterattack** — the primary death check (step 5) runs before the counter step (step 6). Killing a
  `can_counterattack` unit outright is the way to avoid retaliation.
- **If the attacker is killed by a counterattack**: the attacker is removed in the same resolution
  step (step 7). AP was already spent on the attack; death does not refund it.
- **(Direct) If the first blocker along the chosen cardinal line is a friendly unit or a
  friendly/enemy structure**: the shot is **blocked** — no target that direction, even if an enemy
  stands behind the blocker (no shoot-through). The HUD must show this as *blocked-by-friendly*,
  distinct from out-of-range.
- **(Direct) If the first blocker is an enemy but sits beyond `attack_range`**: no legal target — the
  tile walk stops at `attack_range` and finds nothing closer.
- **(Direct) If the first blocker is Impassable terrain**: the line is blocked there; tiles beyond are
  not targetable that direction.
- **(Direct) If two enemies are stacked in the same cardinal line within range**: only the **nearest**
  is targetable (no pierce/shoot-through).
- **(Area) If the chosen target tile is inside the dead zone** (`manhattan_distance < min_range`): not
  targetable — indirect units cannot fire at things too close.
- **(Area) If an intervening unit or Impassable tile sits between an area attacker and its target**:
  it does **not** block — indirect fire ignores line of fire; only the `[min_range, attack_range]`
  ring and enemy-occupancy matter.
- **(Area) If no enemy occupies any tile in the ring**: no legal target (the unit may still have
  moved).
- **If the attacker has already attacked this turn** (`has_attacked == true`): the attack is rejected
  (`can_attack()` false); the unit may still move if AP allows.
- **If the attacker cannot afford `attack_cost`**: the attack is not offered and `attack()` rejects it
  — no AP spent, no state change (AP & Credits Economy `ap_can_afford` gate + `apply_action` atomicity).
- **If the target is an enemy structure (HQ/outpost)**: damage applies via the same formula (with
  structure cover-immunity, Rule 6). **Most structures never counter** — HQ, Economy Outpost, and
  Production Outpost all ship `can_counterattack = false`. The **Defensive Structure is the exception**:
  it has `can_counterattack = true` (the first VS entity to do so) and *does* retaliate when attacked
  while the attacker is a legal target under its own DIRECT range/profile (Rule 7) — even though, like
  every structure, it can never move. If an HQ reaches 0 hp, the win-check fires `GameOver` and no
  further actions are accepted.
- **If a `can_counterattack` defender survives but cannot legally reach the attacker** (attacker
  outside the defender's own range/profile — e.g. a range-1 unit struck from range 3): **no counter**.
  The range-gate is what makes kiting a real tactic.
- **If the same attack action is submitted twice** (double-click / double-send): the second is
  re-validated against the now-updated state — the target may be dead or the attacker already flagged
  `has_attacked` — and is typically rejected. No double-apply.
- **If the attacker stands on a Cover tile**: Cover benefits only the **defender** of an incoming
  attack (it reduces damage *taken*). An attacker gains no offensive bonus from its own tile; Cover
  matters only when the piece is the one being hit.
- **If a *unit* defender is on Cover *and* has a `defense` stat**: both subtract from the same damage
  (they stack), then the min-1 floor applies. (No VS unit has base `defense > 0`; the first live case is
  a Defense-Tech-researched unit standing on Cover — `defense 1 + COVER_DR 1 = 2` mitigation.)
- **If a *structure* defender (HQ / outpost / Defensive Structure) stands on a Cover tile**: Cover has
  **no effect** — structures are cover-immune (Rule 6). The structure mitigates only through its own
  `defense` stat (e.g. an HQ on Cover still takes `max(1, effective_attack − 0 − 2)`, exactly as it
  would on Plain). This is what prevents the HQ (`defense 2`) from stacking to 3 mitigation and
  floor-locking low-attack attackers.
- **If the attacker's owner researches between selecting and committing**: `effective_attack` is
  computed live at resolution from the owner's tech flag, so the committed damage reflects the current
  research state (consistent with Unit System's live-research rule).
- **If a unit tries to target its own tile or a tile at distance 0**: never legal — direct range
  starts at 1, and area `min_range ≥ 1`, so `manhattan_distance == 0` is always outside the target
  set. A unit cannot attack itself.

## Dependencies

**Upstream (this system depends on):**

| System | Nature | Interface |
|--------|--------|-----------|
| Grid & Terrain | Hard | `occupant_at`, `is_cover`, `manhattan_distance`, `neighbors`; `remove` on death; 4-dir adjacency |
| Unit System | Hard | `effective_attack`, `attack_range`, `min_range`, `targeting_mode`, `defense`, `can_counterattack`, `can_attack()`; sets `has_attacked`; hp mutator for damage |
| AP & Credits Economy | Hard | `ap_can_afford(attack_cost)` / `ap_spend(attack_cost)` |
| Game State & Turn Manager | Hard | Attacks applied via `apply_action`; win-check on HQ destruction; clonable state for AI/tests |

**Downstream (systems that depend on this — all HARD):** Command & Action Interface (renders legal
targets, damage preview, blocked-shot reasons, and consumes the new **`legal_targets(unit, from_tile)`**
overload for its after-move attack preview — see Public interface cross-system flag), Game HUD (hp/damage feedback), AI Opponent (uses
`legal_targets`/`preview_damage` to plan — the hypothetical-tile overload is also useful for its lookahead), Faction Identity (may flip `can_counterattack`, adjust
`COVER_DR`/`attack_cost`, or add area-profile units per faction). Each lists Combat Resolution under
its Dependencies when authored.

**Base & Production (#7, Designed 2026-07-21):**
- Owns structure entities (HQ / Economy Outpost / Production Outpost / Defensive Structure), their `hp`
  and `defense` (HQ 2, Defensive Structure 1 — populated into Combat's shared, defender-agnostic
  `defense` field), and the **Defensive Structure's** `attack`/`attack_range`/`can_counterattack` +
  `DEFENSIVE_ATTACK_COST`. Combat targets and damages structures and **accepts the Defensive Structure as
  an attacker** through `attack()` (DIRECT profile), but does not define their stats. Combat's
  HQ-destruction damage is what the Turn Manager's `win_condition` observes. *(Combat does **not** own the
  endgame closeout-drag mechanic — that is Base & Production's, per the systems index. Combat only
  guarantees, via the min-1 floor, that no structure or unit is unkillable.)* The Defensive Structure is
  the **first entity with `can_counterattack = true`** — it exercises Rule 7's counter path that every
  VS unit leaves dormant.

**Provisional (undesigned dependencies):**
- **Research / Tech (#8)** — owns `RESEARCH_ATK_BONUS`; its effect reaches Combat already folded into
  `effective_attack` (read through Unit System), so Combat never reads research state directly.

**Cross-system handoff owed to Unit System (#4, Approved):** this GDD introduces four Unit-owned stat
fields (`targeting_mode`, `min_range`, `defense`, `can_counterattack`) that Unit System's stat schema
and `entities.yaml` must adopt; `attack_range` is reused as the maximum range for both targeting
profiles. See Open Questions and Phase-5 registry sync.

*Bidirectional note:* Grid & Terrain, Unit System, AP & Credits Economy, and Game State & Turn Manager already
list Combat Resolution as a Hard downstream dependent; the `manhattan_distance` registry entry already
anticipates `combat.md` referencing it (to be wired in Phase 5).

## Tuning Knobs

| Knob | Owner | VS Range | Default | Affects | If too high | If too low |
|------|-------|----------|---------|---------|-------------|------------|
| `attack_cost` | Combat | 1–3 | **2** | Attacks/turn vs moving/producing (5 attacks at floor income) | 1 → up to 10 attacks/turn at floor; combat-spam swamps the one-pool tension | 3 → only 3 attacks/turn; combat feels rare, undervalued vs boom/rush |
| `COVER_DR` | Combat | 0–2 | **1** | Value of Cover terrain; positioning incentive | 2 → Scout *and* Trooper floor-lock into Cover (1 dmg); Cover becomes near-immunity, stalls tempo | 0 → Cover flag does nothing; a positioning lever wasted |
| `MIN_DAMAGE` | Combat | 1 (fixed) | **1** | Guarantees no attack is a no-op | >1 needs explicit "grazing hit" design intent — not recommended | 0 → reintroduces the unkillable-feeling stacked-defense case the floor exists to prevent; do not lower |
| `defense` (per unit) | **Unit** | ≥0 | 0 (all VS units) | Flat damage mitigation; durability lever for future units | High values floor-lock low-attack units (see Formulas constraint) | 0 → no mitigation, pure hp/cover model (VS baseline) |
| `min_range` (per unit) | **Unit** | 1–(map) | 1 (direct default) | Size of the indirect dead zone | Large → indirect unit useless up close, easy to swarm | 1 → no dead zone (behaves like direct-range floor) |
| `targeting_mode` (per unit) | **Unit** | {DIRECT, AREA} | DIRECT (all VS units) | Whether a unit uses cardinal-line or circular-indirect fire | — | — (a design identity choice, not a scalar) |
| `can_counterattack` (per unit) | **Unit** | bool | false (all VS units) | Whether a struck unit retaliates | Broadly on → attacking becomes risky, favors turtling, slows tempo | Off → no retaliation (VS baseline); first-strike fully decisive |
| `attack_range` (per unit, = max range) | **Unit** | 1–3 (VS) | 1/2/2/3 | Reach of both profiles | Long ranges dominate spacing | Collapses to melee |

> **Ownership note:** Combat owns only `attack_cost`, `COVER_DR`, and `MIN_DAMAGE`. Everything below
> the divider (`defense`, `min_range`, `targeting_mode`, `can_counterattack`, `attack_range`) is
> **Unit-owned** and listed here because Combat's formulas *consume* them — retune them in
> `unit-system.md`/`entities.yaml`, not here. *(Structures also populate `defense`/`can_counterattack`/
> `attack`/`attack_range` — those structure values are **Base-&-Production-owned**, retuned in
> `base-production.md`; and structures attack at `DEFENSIVE_ATTACK_COST` (B&P-owned), not this
> `attack_cost`.)* `COVER_DR` and `attack_cost` interact: at `COVER_DR = 2`
> with `attack_cost = 2`, more of the roster floor-locks into Cover — treat `COVER_DR = 1` as the safe
> default and 2 as an experimental value to playtest, not a neutral midpoint.

> **Spike-gated:** the whole ranged model (both profiles, `attack_range`, and any future
> `can_counterattack`/`defense`/area unit) is unvalidated — the prototype was pure melee. These are
> intended envelopes, not locked numbers (see Open Questions).

## Visual/Audio Requirements

Combat is where the board's neon "actors" resolve against each other. Anchored to **Neon
Retro-Future** (presentation owned by Command & Action Interface #9 / HUD #10; stated here as
requirements):

**Combat event feedback:**
- **Attack committed:** a fast, flat neon bolt/beam in the attacker's **faction hue** traveling along
  the cardinal line (DIRECT) — a few frames only. Combat VFX must never make the player *wait*
  (Pillar 2 tempo). Flat neon shapes, no soft particle trails.
- **Damage dealt:** one sharp flat flash on the defender's silhouette (hard-edged outline pulse, not a
  glow bloom) plus a damage number. This is the payoff beat of Pillar 2 — "you knew it would land, and
  it did."
- **Death/removal:** a brief (<~0.3s) flat-neon burst in the **defeated unit's faction hue**, then
  immediate removal (no lingering corpse — matches the instant-removal rule). The board clears fast
  for the next action.
- **Counterattack (reserved):** when a future `can_counterattack` unit retaliates, the counter uses
  the same bolt/impact language but **reversed direction and offset in time** (fires after the
  primary), so it reads as *a consequence*, not a second attack or a bug. No VS unit triggers this;
  spec reserved so the interface's attack-feedback language ships counter-ready.

**Pre-commit targeting visualization (Pillar 3 — hard requirement; pixels owned by Interface #9):**
- **DIRECT line-of-fire:** show the cardinal ray across the tiles it crosses, terminating in a **stop
  marker** whose look differs by *why* it stopped.
- **AREA ring + dead zone:** show the full `[min_range, attack_range]` targetable band as a
  neon-outlined ring, and the dead zone (`< min_range`) as a **muted/hatched non-neon fill** — reading
  "excluded," not "empty." (The one justified non-neon board marking, since it communicates a rule,
  not an actor.)
- **Cover-reduced damage:** the pre-commit damage preview must show the **actual post-cover,
  post-defense** number (never the raw attack stat), paired with a cover indicator on the defender's
  tile so the player sees *why* it's lower.
- **Blocked-shot — three visually distinct states** (never one generic grey-out):
  **blocked-by-friendly** (stop marker at your own unit — a positioning rule, not a punishment),
  **out-of-range** (the ray simply ends at `attack_range`), **inside-dead-zone** (AREA only — a
  distinct "too close" marker).

**Damage-number / hp feedback (sells certainty, not surprise):**
- Numbers are **large, flat, high-contrast**, with a short hard-edged punch-up-and-fade — reads
  "known," not "rolled."
- **No rarity-tier color ramp** (no green/blue/purple crit tiers — that language implies variance
  OVERCLOCK doesn't have). Neutral/white or defender-hue; reserve an alert/hot treatment **only** for a
  **lethal hit** (damage ≥ remaining hp), which gets a slightly emphasized number telegraphing the
  death burst.
- hp readout updates **instantly and discretely** (chunky draining pips, not a smooth bar) so the
  player can count exact remaining hp — supports the shots-to-kill legibility from Formulas.

**Audio (GDD-level; final mix owned by the audio pass):**
- **Attack cue** per weight class (Scout light/high zap, Trooper mid, Heavy low thud, Sniper a sharp
  high report with a slight tail reading "long-range"), synthwave-leaning.
- **Impact cue** distinct from the attack cue, ideally scaled to damage dealt (a 1-damage graze
  thinner than a 6-damage hit — audio reinforces the deterministic-weight read).
- **Death cue:** a synth power-down/glitch sting, final and irreversible.
- **Counter cue (reserved):** a delayed/echoing variant of the attack cue so it reads as a reactive
  second event.
- **Blocked-shot cue:** a soft deny tone (not a harsh error buzzer) — "not allowed," not "you erred."

**Principle alignment & risks:**
- Bolts/target-locks/death-bursts default to **faction hue** (Principle 2) — the primary at-a-glance
  read of *who did what to whom*.
- **Risk — neon overuse in a busy fight (Pillar 3):** with multiple attacks/turn, overlapping neon can
  drown the "neon means this matters" signal. Recommend the interface **sequence combat events** (one
  resolves and clears before the next renders) — a pacing requirement that also reinforces Pillar 2
  tempo.
- **Risk — cover/dead-zone markings competing with the neon reservation:** keep the cover icon and
  dead-zone fill in the muted-terrain register so they don't read as faction neon. Flag for the art
  bible's neutral-board-object palette bucket.

> 📌 **Asset Spec** — Visual/audio requirements defined. After the art bible is approved, run
> `/asset-spec system:combat-resolution` for attack-bolt, damage-number, death-burst,
> targeting-overlay, and audio-cue specs.

## UI Requirements

Combat feeds the **pre-commit action menu** — the Advance Wars / Fire Emblem flow the concept
prototype flagged as the highest-value missing affordance (Pillar 3: *see the shot before you take
it*). Combat owns the **data**; the Command & Action Interface (#9) and Game HUD (#10) own the
presentation and interaction.

- On selecting an attacker, the interface queries `legal_targets(unit)` and highlights every valid
  target (DIRECT line-of-fire results and/or AREA ring), plus the three distinct blocked-shot states
  (blocked-by-friendly / out-of-range / inside-dead-zone).
- On hovering/targeting a candidate, `preview_damage(attacker, target)` supplies the **exact** damage
  the attack will deal (post-cover, post-defense, post-research, min-1) — displayed before the player
  commits. Because combat is deterministic, this preview is a *guarantee*, not an estimate.
- The interface must surface the `attack_cost` (2 AP) and gate the action on `can_afford` — an
  unaffordable attack is shown as unavailable, consistent with AP & Credits Economy's affordability rule.
- It must be possible to **cancel** a pending attack (select target → review → back out) before
  committing, mirroring Movement's cancel affordance.
- A reserved counter-preview: once a `can_counterattack` unit exists, the interface should be able to
  show whether a chosen attack will draw a counter (the info is derivable from Combat's rules). Not
  required for the VS (no unit has the flag) but noted so the interface design accounts for it.

Presentation, layout, and input flow are owned by GDDs #9 and #10; this system provides
`legal_targets`, `preview_damage`, and the blocked-reason classification.

> 📌 **UX Flag — Combat Resolution**: The attack-target overlay, pre-commit damage preview, and the
> three blocked-shot states are core to readability and are the heart of the pre-commit action menu.
> In Phase 4 (Pre-Production), run `/ux-design` for the core action interface **before** writing
> epics; stories referencing these should cite `design/ux/[screen].md`, not this GDD.

## Acceptance Criteria

> Combat is a **Logic** system → its BLOCKING gate is the automated Pure-Logic suite below
> (deterministic, no RNG, injected Grid/AP fixtures, no file I/O). Integration ACs are also BLOCKING
> but require real dependencies. The ⟶ criteria are the targeting rules **migrated from Unit System
> (#4)** and are now authoritative here. AREA-profile ACs are **infrastructure/forward-proofing** —
> BLOCKING once an AREA unit ships, advisory while the VS roster is pure-DIRECT.
>
> **Test doubles:** Combat's pure suite injects `effective_attack` as a raw fixture value and never
> re-derives it from base + `RESEARCH_ATK_BONUS` (keeps the gate free of any Research/Unit internals).

**Pure Logic gate (BLOCKING — fake/injected Grid + AP):**

*Damage formula:*
- **GIVEN** a Heavy (atk 5) attacks a Sniper (hp 3, defense 0) on Plain, **WHEN** resolved, **THEN**
  damage = 5 and the Sniper is destroyed.
- **GIVEN** a Scout (atk 2, no cover/defense) attacks a Trooper (hp 6), **WHEN** resolved, **THEN**
  damage = 2, Trooper hp = 4.
- **GIVEN** mitigation ≥ attack (Scout atk 2 vs a `defense 2` **unit** defender on Cover, `COVER_DR 1`),
  **WHEN** resolved, **THEN** damage clamps to `MIN_DAMAGE = 1`, never 0/negative.
- **GIVEN** a Trooper (atk 3) attacks a `defense 0` **unit** defender on Cover, **THEN** damage = 2; **the same
  Trooper vs the same unit defender off Cover**, **THEN** damage = 3.
- **GIVEN** atk 5 vs a `defense 2` **unit** defender, no cover, **THEN** damage = 3; **GIVEN** Sniper atk 6 vs a
  `defense 2` **unit** defender on Cover, **THEN** damage = 6 − 1 − 2 = 3 (cover + defense stack additively for units).
- **GIVEN** a researched Trooper (`effective_attack` fixture = 4), **THEN** damage = 4, not base 3.

*Structure cover-immunity (Rule 6):*
- **GIVEN** a `defense 2` **structure** defender (an HQ fixture) on a Cover tile is attacked by atk 5,
  **WHEN** resolved, **THEN** damage = `max(1, 5 − 0 − 2) = 3` — cover contributes **0** for a
  structure, so the result is identical whether the structure sits on Cover or Plain.
- **GIVEN** the same `defense 2` structure on Cover attacked by a low-attack piece (atk 2), **THEN**
  damage = `max(1, 2 − 0 − 2) = 1` (floor), **not** the `max(1, 2 − 1 − 2)` a cover-stacking structure
  would give — proving the structure never reaches 3 mitigation.

*Attacker on Cover (no offensive bonus):*
- **GIVEN** an attacker standing on a Cover tile attacks a `defense 0` unit defender on a Plain tile,
  **THEN** damage equals the plain result (`max(1, effective_attack − 0 − 0)`) — the attacker's own
  Cover tile has **no** effect on the damage it deals; Cover only ever mitigates damage *taken* by a
  unit defender.

*Damage preview is a guarantee (`preview_damage`):*
- **GIVEN** any legal attacker/target pair, **WHEN** `preview_damage(attacker, target)` is queried and
  then `attack(attacker, target)` is resolved, **THEN** the previewed int **exactly equals** the hp
  actually removed (post-cover, post-defense, post-research, min-1) — `preview_damage` is pure and
  never diverges from the committed damage.

*AP cost & once-per-turn (atomicity):*
- **GIVEN** `has_attacked = false` and ≥ 2 AP, **THEN** `can_attack()` is true and the attack is
  offered.
- **GIVEN** `has_attacked = true`, **WHEN** a second attack is attempted, **THEN** rejected before
  AP/target eval, no AP spent, no state change.
- **GIVEN** a successful attack, **THEN** the attacker's `has_attacked` is set true whether or not the
  target died.
- **GIVEN** < 2 AP, **WHEN** an attack is attempted, **THEN** `can_afford` false → rejected, **no AP
  spent, no `has_attacked` flip, no damage** (atomicity).
- **GIVEN** a legal attack is applied once, **WHEN** the *same* attack action is submitted a second
  time against the now-updated state (attacker already `has_attacked = true`, or the target already
  destroyed/removed), **THEN** the second submission is re-validated and **rejected** — no second
  damage, no second AP deduction, no double-apply (idempotency under double-click / double-send).

*Targeting — DIRECT (⟶ migrated from Unit System, now authoritative):*
- **⟶ GIVEN** a Sniper (range 3) with an enemy exactly 3 tiles away cardinally and nothing
  intervening, **THEN** that enemy is a legal target.
- **⟶ GIVEN** a friendly unit or Impassable tile between attacker and enemy on the line, **THEN** the
  enemy is **not** targetable (LoF blocked by any occupant or Impassable).
- **⟶ GIVEN** two enemies stacked on the same cardinal line in range, **THEN** only the nearest is
  targetable (no pierce).
- **⟶ GIVEN** an enemy on the line but beyond `attack_range` (Trooper range 2, enemy at 3, no closer
  blocker), **THEN** no target that direction.
- **GIVEN** an attempt to target a diagonal/non-cardinal direction, **THEN** rejected (DIRECT
  recognizes only the 4 cardinals; DIRECT range is **cardinal-line distance**, not general manhattan).

*Targeting — AREA (infrastructure / forward-proofing):*
- **GIVEN** an AREA attacker (`min_range 2`, `attack_range 4`) with an enemy at distance 3 and a
  friendly directly between, **THEN** the enemy **is** targetable (ignores LoF).
- **GIVEN** the same attacker and an enemy at distance 1 (inside `min_range`), **THEN** not targetable
  (dead zone); at distance 5 (beyond max), **THEN** not targetable.
- **GIVEN** the same attacker (`min_range 2`, `attack_range 4`) and an enemy at **exactly distance 2**
  (`== min_range`), **THEN** targetable; and at **exactly distance 4** (`== attack_range`), **THEN**
  targetable — the ring bounds are **inclusive** on both ends (off-by-one guard: distances 2 and 4 are
  legal, 1 and 5 are not).
- **GIVEN** an AREA unit fixture with `min_range > attack_range` (an illegal schema state), **THEN** its
  legal-target set is empty and this is surfaced as a **validation/schema error**, not a silent
  soft-lock (Unit/Combat should assert the `min_range ≤ attack_range` invariant).
- **GIVEN** two enemies in the ring, **WHEN** one is declared, **THEN** only that single target takes
  damage (single-target).

*Enemy-only:*
- **GIVEN** a target the attacker owns (unit or own HQ), **THEN** the attack is rejected.

*Structure as attacker (Defensive Structure — Combat's `attack()` accepts a structure attacker):*
- **GIVEN** a Defensive Structure fixture (`attack 4`, `attack_range 2`, DIRECT) fires at an enemy unit
  (`defense 0`, Plain) two tiles away on a clear cardinal line, **WHEN** resolved through `attack()`,
  **THEN** damage = `max(1, 4 − 0 − 0) = 4` — the structure resolves through the *same* targeting +
  damage pipeline as a unit attacker; only the AP charged differs (`DEFENSIVE_ATTACK_COST`, owned by
  Base & Production, not `attack_cost`).
- **GIVEN** the same Defensive Structure attacker and a friendly piece on the cardinal line before the
  enemy, **THEN** the shot is blocked (DIRECT line-of-fire holds identically for a structure attacker).

*Counterattack:*
- **GIVEN** each of the 4 VS units survives a hit, **THEN** no counter fires (`can_counterattack`
  defaults false roster-wide).
- **GIVEN** a `can_counterattack = true` defender survives and the attacker is within the defender's
  **own** range/profile, **THEN** one free counter fires (no AP, sets neither unit's `has_attacked`).
- **GIVEN** a `can_counterattack = true` defender is killed by the primary hit, **THEN** it is removed
  before the counter step and **no counter fires**.
- **GIVEN** a `can_counterattack = true` defender survives but the attacker is **outside** its own
  range/profile (range-1 defender struck from range 3), **THEN** no counter.
- **GIVEN** a counter kills the attacker, **THEN** the attacker is removed and **no counter-to-the-
  counter** occurs (structurally one counter step per `apply_action`).

*Death & determinism:*
- **GIVEN** hp reaches exactly 0, **THEN** the piece is removed from Grid occupancy the same step and
  its tile is immediately empty/targetable.
- **GIVEN** a state `S` and two independent clones of it (`A = clone(S)`, `B = clone(S)`), **WHEN** the
  same `attack(attacker, target)` is applied to `A` and to `B`, **THEN** the returned `damage` ints are
  equal **AND** `A` and `B` are equal under the defined state-equality predicate — every affected
  entity's `current_hp`, `position`, `has_attacked`, `destroyed` flag, and the Grid occupancy map all
  match (no RNG, stable iteration order). *(State-equality is this field-wise comparison, not byte-level
  serialization — no hashing/serialization infrastructure is required or implied.)*
- **GIVEN** a state `S` and a clone `C = clone(S)`, **WHEN** `attack(...)` is applied to `C`, **THEN**
  `C` reflects the attack and **`S` is unchanged** under the same state-equality predicate (clone
  isolation — the resolution never mutates the source state, so AI look-ahead is side-effect-free).

**Integration gate (BLOCKING — real Grid + AP + Turn Manager + Unit):**
- **GIVEN** a legal, affordable attack, **WHEN** routed through `apply_action`, **THEN** AP pool,
  `has_attacked`, and target hp all reflect one atomic commit; **GIVEN** an unaffordable one, **THEN**
  the real pool and Grid are unchanged.
- **GIVEN** enough AP to move and attack, **THEN** both **move-then-attack** and **attack-then-move**
  succeed the same turn with correct AP deduction.
- **GIVEN** an enemy HQ at hp = the attacker's damage, **WHEN** the attack resolves, **THEN** HQ
  hp → 0, Turn Manager's win-check fires `GameOver(winner = opponent)` in the same action, and any
  subsequent action (either side) is rejected.
- **GIVEN** a real Grid with a real ally 1 tile away and a real enemy 2 tiles away, **WHEN** a Trooper
  (range 2) targets down that line, **THEN** the end-to-end query returns no target (LoF holds against
  the real Grid).
- **GIVEN** a real fixture where a `can_counterattack` defender survives an in-range attack, **WHEN**
  resolved through the real pipeline, **THEN** both primary and counter hp changes are present in the
  authoritative state after `apply_action` returns.

*(Simultaneous double-HQ destruction is **out of scope for the VS** — single-target combat makes it
impossible; the Turn Manager owns the reserved "non-active player wins" rule for future AoE.)*

## Open Questions

| Question | Owner | Notes / target |
|----------|-------|----------------|
| **Ranged combat is UNVALIDATED** — the prototype was pure melee (range 1). Does the DIRECT cardinal-line/first-blocker model feel good, and are `attack_range`/damage balanced across the roster? | game-designer / Combat | **Highest risk in this GDD.** Validate the whole `range > 1` model in the vertical slice or a focused **combat spike** before the numbers lock. |
| **Sniper no-counter hypothesis** — the damage formula has no attacker-range term, and `can_counterattack` is off for every VS unit, so nothing in Combat's own math punishes a Sniper firing from range 3. It 1-shots Scout/Sniper, 2-shots Trooper/Heavy. | game-designer / Combat / Movement | **Named spike hypothesis (structural).** In the spike, measure **outcome variance/dispersion** (the Sniper is bimodal — oppressive or dead), not just mean win-rate. If structural, the fix is a positioning lever (partial ZoC, move-then-attack cost) or a *specific* unit given `can_counterattack` — not `attack_cost`. |
| Should AREA fire ever become true multi-tile **splash/AoE** (vs the VS single-target-in-ring)? | Combat (#6) | VS = single-target. AoE (and the Heavy-splash question from Unit System) is an Alpha lever; it would need friendly-fire rules + a blast-radius stat + the reserved simultaneous-HQ rule. |
| Is **binary Cover** (`COVER_DR = 1`) enough, or does Cover want degrees (light/heavy)? | Combat / Grid | VS = binary. Degrees are an Alpha consideration; would add a per-tile cover-magnitude to Grid. |
| Does **line-of-fire blocking** make Impassable / Procedural-Center bands too strong as sightline walls? | game-designer / Grid / Combat | Watch in playtest — Grid's Impassable now doubles as a line-of-fire blocker for DIRECT fire; `PROC_DENSITY`/`PROC_FEATURE_MIX` may need re-tuning. (Grid and Unit raise the same flag.) |
| Is flat **`attack_cost = 2`** right, or is any unit's attack mispriced at a flat rate? | game-designer / economy-designer | Decided flat 2 (keeps legibility; Unit's per-AP audit assumes a constant 2-AP denominator). Revisit only if playtest shows a specific unit's attack is over/under-valued at 2. **★ Raised again 2026-08-21 and DEFERRED, decision unchanged** — the trigger above had not fired (S5-04 has not run), and the prompt was a rendering side-effect rather than playtest evidence. A candidate spread (Scout 1 / Trooper 2 / Sniper 2 / Heavy 3, roster mean held at 2) and the full list of what would need re-checking are recorded in `production/post-gate-backlog.md` §1. |
| When **defense / counter / AREA units** are eventually added, do the infrastructure rules hold? | Unit (#4) / Combat (#6) / Base & Production (#7) | **Partly realized:** Base & Production's **Defensive Structure** is the first entity to populate `defense` (1) and set `can_counterattack = true`, exercising Rule 7's counter path + the shared `defense` field. Re-validate the **defense-stacking constraint** for *units* (a unit's `defense + COVER_DR < ` lowest `effective_attack`; first live at a Defense-Tech unit on Cover = 2 mitigation) and the DIRECT-counter profile when it playtests. **Structures no longer participate** — cover-immunity (Rule 6) means the HQ's `defense 2` never stacks with Cover, resolving the earlier "keep structures off Cover" caveat by rule rather than by placement. AREA remains dormant (`DIRECT` everywhere in the VS). |
| Does the **min-1 damage floor** worsen the endgame closeout-drag? | Base & Production (#7) | **CONFIRMED not a factor** — Base & Production (#7, Designed 2026-07-21) brakes the drag via production rate/quality (HQ Scouts-only cap 2 + expensive/destroyable Production Outpost), not the damage formula. `systems-designer` re-affirmed: the min-1 floor only binds for Scout-tier attackers into Cover and does not participate in the closeout mechanic. Combat only guarantees nothing is unkillable. |
| **Cross-system handoff to Unit System (#4, Approved):** add stat fields `targeting_mode` (enum, default DIRECT), `min_range` (int, default 1), `defense` (int, default 0), `can_counterattack` (bool, default false) to the unit schema + `entities.yaml`; `attack_range` becomes the max range for both profiles. | Unit (#4) / this session | **Action item.** Combat specs the resolution; Unit owns the fields. Partly actioned in Phase 5 (registry candidates); Unit System's GDD should be revised to document the four fields. Consider `/propagate-design-change`. |
