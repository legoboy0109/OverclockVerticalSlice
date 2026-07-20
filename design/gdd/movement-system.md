# Movement System

> **Status**: In Revision (was Approved 2026-07-19; revised 2026-07-20 to absorb the Unit-System soft-cap
> surcharge — the new `move_path_cost` split and reachability change need an independent `/design-review`)
> **Author**: user + main session
> **Last Updated**: 2026-07-20
> **Implements Pillar**: Pillar 3 (Readable Board — reachable tiles shown before committing); Pillar 1 (movement spends from the one AP pool); Pillar 2 (positioning is tempo)
> **Priority / Layer**: Vertical Slice / Core (system #5)

## Overview

Movement System governs how units traverse the grid: which tiles a unit can reach this turn, what
each move costs, and what blocks a path. Movement draws from the shared AP pool like everything else
— a unit spends its `move_cost` in AP for each tile it enters — so *where* you move and *how far* is
a tempo decision, not a free repositioning. The signature rule (and the prototype's #1 fix): a unit
may **path through its own units** but must stop on an empty tile, so friendly pieces never trap each
other. Reachability is computed as a deterministic search over the authoritative grid, and the full
reachable set is shown to the player before they commit (Pillar 3). Movement is the spatial half of
the tempo duel: controlling space, threatening lanes, and repositioning under a budget.

## Player Fantasy

The player engages with movement directly and constantly. The fantasy is **fluid, legible
maneuver** — you always see exactly where a unit can go and what it costs, so positioning feels like
a clean tactical choice, never a fight with the controls (the exact frustration the prototype
surfaced when friendly units blocked each other). Moving *through* your own formation to reposition,
seeing a Scout's wide reach vs. a Heavy's short shuffle, threading a unit past a comrade to seize a
lane — these should feel crisp and deliberate. This serves Pillar 3 (*Readable Board, Deep
Decisions*): the depth is in choosing *where*, and the system's job is to make the *where* perfectly
clear before you spend the AP.

## Detailed Rules

### Core Rules

1. **A unit moves one tile at a time along cardinal directions** (4-directional, per
   `grid_adjacency_mode` — no diagonals). A "move" is a path from the unit's tile to a chosen
   destination tile.
2. **Each tile entered costs the unit's `move_cost` in AP** (owned by Unit System: Scout 1 /
   Trooper 2 / Heavy 3 / Sniper 2), **until the unit's `soft_move_cap` is exceeded.** The first
   `soft_move_cap` tiles a unit enters *cumulatively this turn* each cost the base `move_cost`; every
   tile beyond that costs a single **flat surcharge** of `ceil(move_cost × SOFT_MOVE_PENALTY)` AP (see
   the Formulas section). `soft_move_cap` (per-unit) and `SOFT_MOVE_PENALTY` (a global constant) are
   **owned by Unit System**; Movement owns only the summation below. This is a **two-level step, not a
   multi-tier curve** — a brake on deep single-turn over-extension/rushes, not a per-step kiting tax.
   AP is spent via AP Economy's `spend()`.
3. **Traversal (what a path may pass *through*):** a path may cross tiles occupied by **friendly
   units**. It may **not** cross: enemy units, **any structure** (HQ or outpost, friendly or enemy),
   or **Impassable** terrain. Those are hard blockers.
4. **Destination (where a unit may *stop*):** the destination must be an **empty, passable** tile
   (not occupied by any unit or structure, terrain ≠ Impassable). You can pass through a friendly
   unit but cannot end your move on top of it (Grid single-occupant invariant).
5. **Reachability:** a tile is reachable this turn if there exists a traversable path to it whose
   total cost ≤ the unit's `current_ap`, **and** the tile is a valid destination (Rule 4). The full
   reachable set is computed deterministically and shown to the player before committing.
6. **A unit may move multiple times per turn**, gated only by AP — there is no per-unit move limit.
   Each tile entered increments the unit's `tiles_moved_this_turn` counter (Unit-owned state); the
   soft-cap split (Rule 2) is keyed off this **cumulative** count, so splitting a long move into
   several `move()` calls does **not** reset the count or dodge the surcharge. The counter is reset by
   Unit System's `reset_turn_flags()` at the owner's start-of-turn (Movement never resets it).
   A unit may also move and then attack (Combat's `has_attacked` is separate; movement never sets it).
7. **No zone of control in the Vertical Slice:** being adjacent to an enemy does not stop or slow a
   unit — enemies block only the tile they occupy, not the tiles around them. (ZoC is an Alpha
   consideration; see Open Questions.)
8. **Movement is deterministic:** the reachable set and the chosen path's cost are pure functions of
   the grid state and the unit — no RNG, stable iteration order, headless-computable (for AI + tests).

### States and Transitions

Movement has no persistent state machine — a move is an atomic transition applied via the turn
manager's `apply_action`:

| Step | Effect |
|------|--------|
| Player/AI selects a unit | Reachable set computed and (for the player) displayed |
| A reachable destination is chosen | Path cost validated against `current_ap` (`can_afford`) |
| Move applied | `spend(move_path_cost)` (soft-cap-aware, see Formulas); `tiles_moved_this_turn += tiles entered`; unit's grid position updated (old tile emptied, new tile occupied); atomic |
| (repeat) | Unit may move again if AP remains and a valid destination exists — the next move's cost continues from the current `tiles_moved_this_turn` |

### Interactions with Other Systems

| System | Data in | Data out | Interface owner |
|--------|---------|----------|-----------------|
| Grid & Terrain | neighbors, passability (Impassable), occupancy (unit/structure at a tile) | — | Grid |
| Unit System | `move_cost`, `soft_move_cap`, `SOFT_MOVE_PENALTY` per unit; reads/writes `tiles_moved_this_turn` | updated `tiles_moved_this_turn` | Unit System owns the values + the counter field + `reset_turn_flags()`; Movement owns the surcharge summation |
| AP Economy | `can_afford` (gates reachable set) / `spend` (on move) | — | AP Economy owns the pool |
| Game State & Turn Manager | applies the move via `apply_action`; move is part of clonable state | new unit position | Turn manager (mutation path) |
| Combat Resolution | a moved unit may then attack (separate action) | — | Combat (movement doesn't trigger it) |
| Base & Production | (produced units are *placed*, not *moved* — placement owned there) | — | Base & Production |
| Command & Action Interface / Game HUD | reachable set + path preview + AP cost | display before commit | those systems own presentation |

**Public interface:** `reachable(unit) -> set<tile, cost>` (side-effect-free) · `move(unit, destination) -> Result`
(validates path + `can_afford`, spends, updates position; atomic).

## Formulas

### `move_path_cost` (soft-cap-aware)

A path's cost splits into tiles billed at the base `move_cost` (those within the unit's remaining
soft-cap budget) and tiles billed at the flat over-cap surcharge:

```
let c = unit.soft_move_cap                       # per-unit threshold (Unit-owned)
let m = unit.tiles_moved_this_turn               # cumulative tiles already entered this turn
let t = tiles_entered(path)                       # tiles this path enters (excludes start tile)
let surcharge = ceil(unit.move_cost × SOFT_MOVE_PENALTY)   # flat, per over-cap tile; ceil ⇒ integer AP

base_tiles      = max(0, min(t, c − m))          # tiles still within the soft-cap budget
overcap_tiles   = t − base_tiles                  # tiles past the cap
move_path_cost  = base_tiles × unit.move_cost + overcap_tiles × surcharge
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `unit.move_cost` | int | 1–3 | AP per in-cap tile (Unit System: Scout 1 / Trooper 2 / Heavy 3 / Sniper 2) |
| `unit.soft_move_cap` | int | 2–5 | Tiles at base cost before the surcharge (Unit-owned: Scout 4 / Trooper 3 / Heavy 2 / Sniper 3) |
| `unit.tiles_moved_this_turn` | int | 0 – (board) | Cumulative tiles entered so far this turn (Unit-owned state; reset at start-of-turn) |
| `SOFT_MOVE_PENALTY` | float const | 1.5–3.0 | Over-cap multiplier (Unit-owned global constant; default 2.0) |
| `tiles_entered(path)` | int | 0 – path length | Tiles the path enters (excludes the start tile) |
| `move_path_cost` | int | 0 – `current_ap` | AP spent for the move (always integer — `ceil` on the surcharge) |

**Integer-AP invariant:** because `SOFT_MOVE_PENALTY` × an odd `move_cost` can be fractional
(e.g. Scout 1 × 1.5 = 1.5), the surcharge is `ceil(move_cost × SOFT_MOVE_PENALTY)` — rounded up per
over-cap tile, so every cost stays an integer and is always ≥ `move_cost`. (This replaces this GDD's
former "all costs are integers, fractions impossible" claim — see Edge Cases.)

**Example (in-cap):** a Trooper (`move_cost` 2, `soft_move_cap` 3, `tiles_moved_this_turn` 0) moving a
3-tile path pays 3 × 2 = 6 AP — no surcharge (3 ≤ cap). **Example (over-cap):** the same Trooper then
moving 2 more tiles (now `m` = 3, at the cap) pays 2 × `ceil(2 × 2.0)` = 2 × 4 = 8 AP for those 2
tiles. **Example (Scout, split move):** a Scout (`move_cost` 1, cap 4, penalty 2.0) moving 6 tiles in
one turn — whether as one path or several — pays 4 × 1 + 2 × `ceil(1 × 2.0)` = 4 + 4 = 8 AP; the
cumulative counter prevents chunking from resetting the cheap budget.

### `reachable(unit)` — reachable-tile search

Deterministic uniform-cost search (Dijkstra) from the unit's tile:
- **Edge cost** to enter a passable tile is **depth-dependent** (no longer uniform): it is
  `unit.move_cost` while the tile's *cumulative depth* (`tiles_moved_this_turn` + steps taken along
  the path so far) is ≤ `soft_move_cap`, and `ceil(move_cost × SOFT_MOVE_PENALTY)` beyond it. Because
  the per-tile cost only ever **rises** with depth (surcharge ≥ base) and depth increases along every
  path, accumulated path cost is still monotonic — so Dijkstra remains correct; the search accumulates
  the soft-cap-aware `move_path_cost` rather than `move_cost × depth`.
- **Traversable nodes:** empty tiles and **friendly-unit-occupied** tiles (pass-through). **Blocked
  nodes** (not expanded): enemy units, all structures, Impassable terrain.
- **Budget:** accumulate cost ≤ `current_ap`.
- **Valid destinations returned:** reachable tiles that are **empty & passable** (Rule 4) — a
  friendly-occupied tile can be traversed but is excluded from the returned destination set.

**Output:** a set of `{tile, min_cost}` for every legal stop. Max reach is no longer a simple
`floor(current_ap / move_cost)` — the surcharge shortens deep paths — but the search still respects
blockers, board shape, and the soft cap. **Example:** a fresh Scout (`move_cost` 1, cap 4, penalty
2.0) with 5 AP reaches any empty tile within 4 steps at base cost (4 AP), then can afford **at most
0** further tiles (a 5th tile would cost `ceil(1×2.0)` = 2 AP, exceeding the remaining 1 AP) — so its
5-AP reach is 4 tiles, not 5. Under the old uniform rule it would have been 5.

## Edge Cases

- **If `unit.move_cost > current_ap`**: the reachable set is empty — the unit cannot move this turn.
- **If a unit is boxed in** by blockers (enemies/structures/Impassable) with no empty tile reachable
  even through friendlies: reachable set is empty; the unit simply cannot move (not an error).
- **If a friendly unit sits between the mover and an empty tile**: the mover **may path through** the
  friendly to reach the empty tile beyond (cost still counts per tile entered) — the prototype fix.
- **If an enemy unit or any structure sits in the only path**: it **blocks** — the tiles beyond are
  unreachable via that path (no pass-through, no ZoC halo, just the occupied tile is impassable).
- **If a chosen destination is occupied** (unit or structure) or Impassable: it is not in the valid
  destination set and `move()` rejects it — you cannot stop there.
- **If a unit moves, then the board changes** (e.g. it or a blocker is destroyed in combat) and it
  moves again: reachability is recomputed fresh each time from current state (no stale cache).
- **If two equal-cost paths reach the same tile**: the destination is reachable at that cost; which
  underlying path is "the" path is irrelevant to cost — but path selection is deterministic (stable
  order) so replays and AI clones match exactly.
- **If the over-cap surcharge would be fractional** (`move_cost × SOFT_MOVE_PENALTY` not integer, e.g.
  Scout 1 × 1.5 = 1.5): the surcharge is `ceil(...)`, rounded **up** per over-cap tile — so all AP
  costs remain integers and are always ≥ `move_cost`. (Supersedes the earlier "fractions impossible"
  assumption, which no longer holds once `SOFT_MOVE_PENALTY` is in play.)
- **If a unit moves past its `soft_move_cap` (cumulative this turn)**: each tile past the cap costs
  `ceil(move_cost × SOFT_MOVE_PENALTY)` instead of `move_cost`. The unit is never *blocked* from
  over-extending — it just pays the surcharge, gated normally by `can_afford` on the surcharged total.
  **Worked example:** a Heavy (`move_cost` 3, cap 2, penalty 2.0) moving 3 tiles pays 2×3 + 1×`ceil(3×2.0)`
  = 6 + 6 = 12 AP — over a full floor turn's income on movement alone, which is the intended brake on
  bulk reach for a heavy body.
- **If a unit splits one long trek across several `move()` calls**: the surcharge still applies from
  the cumulative `tiles_moved_this_turn` — chunking does not reset the cheap budget (no exploit).

## Dependencies

**Upstream (this system depends on):**

| System | Nature | Interface |
|--------|--------|-----------|
| Grid & Terrain | Hard | Neighbors, passability, occupancy; 4-dir adjacency |
| Unit System | Hard | `move_cost`, `soft_move_cap`, `SOFT_MOVE_PENALTY`, `tiles_moved_this_turn` per unit; `reset_turn_flags()` resets the counter |
| AP Economy | Hard | `can_afford` (gates reachability) / `spend` (on move) |
| Game State & Turn Manager | Hard | Applies moves via `apply_action`; clonable state for AI/tests |

**Downstream (systems that depend on this — HARD):** Command & Action Interface (renders reachable
set + path preview + cost), AI Opponent (uses `reachable` to plan). Each lists Movement under its
Dependencies when authored.

**Provisional / spike-gated:** the soft-cap surcharge inputs (`soft_move_cap` per unit,
`SOFT_MOVE_PENALTY`, default 2.0) are **unvalidated** — Unit System owns them and flags the whole
ranged/reach model for a combat spike before the numbers lock. The surcharge *formula* here (the
summation, `ceil` rule, and depth-dependent reachability) is Movement-owned and needs `/design-review`.

## Tuning Knobs

Movement owns few numeric knobs of its own — its main values (`move_cost` per unit) are owned by
Unit System. What it does own are mostly **design-rule toggles**, fixed for the Vertical Slice:

| Knob | VS Value | Affects | Notes |
|------|----------|---------|-------|
| Friendly pass-through | ON (fixed VS) | Whether units block their own units | The prototype fix; turning it off re-introduces the trap |
| Adjacency / diagonal movement | 4-dir (fixed) | Reachability shape | Owned by Grid (`grid_adjacency_mode`); 8-dir would rebalance everything |
| Zone of control | OFF (fixed VS) | Whether adjacent enemies stop movement | Alpha consideration (Open Questions) |
| Per-unit `move_cost` | (owned by Unit System) | Reach per AP | Referenced, not owned here — 1/2/3/2 |
| Per-unit `soft_move_cap` | (owned by Unit System) | Tiles at base cost before the surcharge | Referenced, not owned here — Scout 4 / Trooper 3 / Heavy 2 / Sniper 3 (PROVISIONAL, spike-gated) |
| `SOFT_MOVE_PENALTY` | (owned by Unit System) | Over-cap surcharge steepness | Referenced, not owned here — global const, default 2.0, range 1.5–3.0 (PROVISIONAL, spike-gated) |
| Difficult-terrain move multiplier | none (VS) | Variable tile entry cost | Deferred to Alpha; Movement owns it if added |

## Visual/Audio Requirements

Movement's readability is central to Pillar 3 (presentation owned by the Command & Action Interface /
HUD; stated here as requirements):
- **Reachable-tile highlight:** on selecting a unit, all valid destinations are clearly highlighted;
  friendly tiles the unit can pass *through* but not stop on read differently from valid stops.
- **Path + cost preview:** hovering/targeting a destination previews the path and its exact AP cost
  **before** committing (see-the-cost-before-you-pay — Pillar 3, and the prototype's requested
  action-preview affordance).
- **Move feedback:** a crisp slide/step animation along the path and a movement SFX; a "no AP / can't
  move" state reads clearly (dimmed unit).
- Neon Retro-Future: highlights use the reserved neon accent ("neon means this matters").

> 📌 **Asset Spec** — Visual requirements defined. After the art bible is approved, run
> `/asset-spec system:movement-system` for highlight/preview visual specs.

## UI Requirements

The reachable-tile overlay, path preview, and AP-cost readout are the core UI this system feeds. They
are owned and designed by the Command & Action Interface (#9) and Game HUD (#10); this system provides
`reachable(unit)` and per-path cost. It must be possible to *cancel* a pending move before committing.

> 📌 **UX Flag — Movement System**: Reachable-tile highlighting + path/cost preview are core to
> readability and are the heart of the pre-commit action menu. In Phase 4 (Pre-Production), run
> `/ux-design` for the core action interface **before** writing epics; stories cite
> `design/ux/[screen].md`, not this GDD.

## Acceptance Criteria

- **GIVEN** a Scout (`move_cost` 1) with 5 AP on open terrain, **WHEN** `reachable` is computed,
  **THEN** every empty passable tile within a 5-step traversable path is returned as a valid stop.
- **GIVEN** a Trooper (`move_cost` 2) with 5 AP, **WHEN** it moves a 2-tile path, **THEN** 4 AP are
  spent (1 remains); **WHEN** a 3-tile path (cost 6) is considered, **THEN** it is not offered.
- **GIVEN** a friendly unit between the mover and an empty tile, **WHEN** `reachable` is computed,
  **THEN** the empty tile beyond is reachable (the mover paths through the friendly).
- **GIVEN** an enemy unit or a structure between the mover and a tile, **WHEN** `reachable` is
  computed, **THEN** the path is blocked there and tiles reachable only through it are excluded.
- **GIVEN** a friendly-occupied tile, **WHEN** it is considered as a destination, **THEN** it is not
  a valid stop (`move` to it is rejected); an Impassable tile is likewise never a valid stop.
- **GIVEN** a unit adjacent to an enemy, **WHEN** it moves past/around the enemy, **THEN** it is not
  stopped or slowed (no zone of control in the VS).
- **GIVEN** a unit with AP remaining after a move, **WHEN** it moves again, **THEN** the second move
  is allowed and charged normally (AP-gated only).
- **GIVEN** a unit whose cumulative `tiles_moved_this_turn` is at or above its `soft_move_cap`,
  **WHEN** it enters a further tile, **THEN** that tile costs `ceil(move_cost × SOFT_MOVE_PENALTY)`,
  not `move_cost` (surcharge applied per over-cap tile).
- **GIVEN** a unit that could reach tile T in one move, **WHEN** the same net displacement is split
  into two `move()` calls, **THEN** the total AP charged is identical (cumulative counter — chunking
  never resets the cheap budget).
- **GIVEN** an odd-`move_cost` unit (e.g. Scout `move_cost` 1) and a fractional
  `move_cost × SOFT_MOVE_PENALTY`, **WHEN** an over-cap tile is billed, **THEN** the charge is the
  `ceil` (integer) value and the total AP spent is an integer.
- **GIVEN** the same grid state and unit, **WHEN** `reachable` is computed twice (incl. on a cloned
  state), **THEN** the results are identical (determinism; headless-computable).
- **GIVEN** a unit whose `move_cost` exceeds `current_ap`, **WHEN** `reachable` is computed, **THEN**
  it returns the empty set.

## Open Questions

| Question | Owner | Notes / target |
|----------|-------|----------------|
| Difficult terrain (variable per-tile move cost — e.g. slow tiles, high ground)? | Movement / Grid | Deferred to Alpha; Grid flagged this and Movement owns the mechanic |
| Zone of control (adjacent enemies stop/slow movement)? | game-designer | VS = OFF; ZoC adds tactical depth but complicates readability (Pillar 3) — Alpha |
| Should friendly *structures* be pass-through too, or only friendly units? | game-designer | This GDD sets: only friendly **units** are pass-through; all structures block. Confirm in review |
| Overwatch / reaction moves (a unit reacting during the enemy turn)? | Combat / game-designer | Out of VS scope; would break the strict turn model — Alpha+ |
| Ranged kiting emerges from these rules (no ZoC + no overwatch + multiple AP-gated moves + move-then-attack lets a ranged unit move → shoot → retreat freely). | game-designer / Combat | Watch item — the cross-cutting RANGED-COMBAT decision flags kiting (esp. Sniper, range 3 / `move_cost` 2) as the highest-risk *unvalidated* behavior. Movement is half of what enables it. **Note: the soft-cap surcharge (added 2026-07-20) does NOT tax kiting** — a 1–2 tile standoff kite sits under every unit's `soft_move_cap`; the surcharge only brakes deep single-turn over-extension/rushes. If kiting itself proves degenerate in the spike, the lever is a *separate* mechanism (partial ZoC / move-then-attack cost), not a lower soft cap. |
| Does the depth-dependent reachability cost (soft-cap surcharge) hurt reachable-set compute cost or preview clarity? | Movement / Command & Action Interface | The search stays Dijkstra (monotonic cost) but is no longer uniform-cost — verify the reachable-set overlay still reads clearly when tiles past the cap cost more (Pillar 3). Spike/UX watch item |
