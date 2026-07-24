# Movement System

> **Status**: **Approved** (2026-07-21 confirming re-review — 5 specialists). The formula core was
> independently re-derived as sound (min-length ≡ min-cost licenses the depth-only BFS/Dijkstra; no
> degenerate boundary outputs). Three blocking gaps from that re-review — path-selection determinism
> AC, board-change/no-stale-cache AC, and the `move_cost ≥ 1` monotonicity precondition — were fixed
> in-file same session, plus doc-honesty notes (Player-Fantasy caveat, no-positional-deterrence
> decision, named kiting fallback owner+lever, split blocker AC, impl-note precision). Numbers remain
> **spike-gated** (soft-cap/range values ← ranged-combat spike). History: Approved 2026-07-19 → In
> Revision 2026-07-20 (soft-cap surcharge) → NEEDS REVISION re-review 2026-07-20 (4 items fixed) →
> Approved 2026-07-21. See `reviews/movement-system-review-log.md`.
> **Author**: user + main session
> **Last Updated**: 2026-07-21
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

> **Honest caveat (the soft cap's cost to this fantasy):** the `soft_move_cap` surcharge (added
> 2026-07-20) introduces **one extra thing the player must be aware of** — a cheap-tiles budget that
> is cumulative across the turn and shrinks as a unit moves. "Legible maneuver" here does **not** mean
> "zero ruleset awareness"; it means the reachable overlay must carry that state *visually* so the
> player never has to track it mentally (in-cap vs over-cap tiles rendered distinctly, reflecting the
> unit's current `tiles_moved_this_turn` — a hard requirement, see Visual/Audio Requirements). The
> depth-dependent cost is a deliberate, spike-gated design cost paid *for* an over-extension brake; the
> overlay is how Pillar 3 is honored despite it, not a claim the extra regime is invisible.

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
   consideration; see Open Questions.) **Stated design consequence (deliberate, not emergent):** with
   no ZoC, no overwatch, unlimited AP-gated moves, and move-then-attack all in play, the VS has **no
   positional deterrence** — an attacker can freely path around a defensive line to reach softer
   backline targets, constrained only by AP, never by any spatial commitment the defender can impose.
   Fast, fluid flanking over WW2-style front lines is the intended feel; this is load-bearing, not an
   oversight, and Combat/AI reviewers should treat it as a fixed VS assumption.
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
| Base & Production | (produced units are *placed*, not *moved* — placement owned there); **structures block all traversal (Rule 3), incl. for their owner** — so *your own* structure placement can reduce *your own* army's reachability (a corridor-blocking outpost/HQ removes a friendly pass-through route). A placement-side interaction Base & Production should be aware of. | — | Base & Production |
| Command & Action Interface / Game HUD | reachable set + path preview + AP cost + **per-tile `is_surcharged` flag** (drives the in-cap vs over-cap overlay) | display before commit | those systems own presentation |

**Public interface:** `reachable(unit) -> set<{tile, min_cost, is_surcharged}>` (side-effect-free) · `move(unit, destination) -> Result`
(validates path + `can_afford`, spends, updates position; atomic).

**Cross-system flag (owed by Command & Action Interface #9's `/design-review` 2026-07-22 — propagated here):** `reachable()`'s return now carries an explicit **`is_surcharged: bool` per tile** — true when the tile's `min_cost` includes at least one over-cap surcharge step. This makes the in-cap/over-cap split of the overlay a *contract*, not a UI inference from `min_cost` (which cannot cleanly separate a mixed in-cap/over-cap path — see this GDD's Visual/Audio requirement that the two render distinctly). #9 renders it verbatim and holds no surcharge constant of its own. The flag is computed by the same Dijkstra search that produces `min_cost` (it already knows, per depth, whether a step crossed `soft_move_cap`), so it adds no new traversal. Final field name/shape reconciled at `/create-architecture`.

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

**Monotonicity precondition (required for the search shortcut below):** `move_cost ≥ 1` and
`soft_move_cap ≥ 0` for every unit (enforced by Unit System's schema — Core Rule 3). This is not a
cosmetic bound: the `reachable()` search's correctness (min-length ≡ min-cost, licensing the
depth-only BFS/Dijkstra) depends on per-tile cost being **strictly positive and non-decreasing in
path depth**. A hypothetical `move_cost = 0` unit would make every path length cost-tie, silently
breaking that argument; `soft_move_cap` may be 0 (all tiles surcharged) and the formula still degrades
gracefully, but `move_cost` must never be 0.

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
  - **Why keying the settled-cost table by `tile` alone (not `(tile, depth)`) is safe:** given a fixed
    starting `tiles_moved_this_turn`, this formula makes path cost a pure function of path **length** —
    so the minimum-**length** path to a tile is always a minimum-**cost** path to it (min-length ≡
    min-cost). Two paths reaching the same tile at the same length are cost-identical *regardless of
    where along them the cap was crossed*, so a depth-un-keyed per-tile relaxation cannot miss a
    cheaper-longer path. This min-length≡min-cost equivalence — distinct from mere length-purity — is
    the actual property licensing BFS/Dijkstra without `(tile, depth)` keys; spelled out here for
    implementers.
- **Traversable nodes:** empty tiles and **friendly-unit-occupied** tiles (pass-through). **Blocked
  nodes** (not expanded): enemy units, all structures, Impassable terrain.
- **Budget:** accumulate cost ≤ `current_ap`.
- **Valid destinations returned:** reachable tiles that are **empty & passable** (Rule 4) — a
  friendly-occupied tile can be traversed but is excluded from the returned destination set.

**Output:** a set of `{tile, min_cost, is_surcharged}` for every legal stop (`is_surcharged` true when `min_cost` includes ≥1 over-cap step — see the Public-interface cross-system flag). Max reach is no longer a simple
`floor(current_ap / move_cost)` — the surcharge shortens deep paths — but the search still respects
blockers, board shape, and the soft cap. **Example:** a fresh Scout (`move_cost` 1, cap 4, penalty
2.0) with 5 AP reaches any empty tile within 4 steps at base cost (4 AP), then can afford **at most
0** further tiles (a 5th tile would cost `ceil(1×2.0)` = 2 AP, exceeding the remaining 1 AP) — so its
5-AP reach is 4 tiles, not 5. Under the old uniform rule it would have been 5.

**Agreement invariant (reachable ⇔ billed).** For any destination `T` in `reachable(unit)`, the
reported `min_cost` **equals** the `move_path_cost` that `move(unit, T)` actually bills for the path
it takes to `T` — both use the identical soft-cap-aware summation over the same tile sequence, so the
previewed cost is *always exactly* what is charged (Pillar 3: see the cost before you pay). This holds
on the authoritative state and on any `clone()`. The two code paths (search vs. billing) must never
diverge; an AC asserts it directly.

> **The invariant is actually stronger than "same tile sequence."** Because cost depends only on path
> **length** (given the same starting `tiles_moved_this_turn`), it holds even if `move()`'s concrete
> route differs *tile-for-tile* from the one `reachable()` costed — any two equal-length paths to `T`
> bill identically. The real guarantee is **same-length ⇒ same-cost**, which is robust to
> implementation divergence in *which* shortest path is walked; implementers need only match path
> *length*, not path identity.

> 📐 **Implementation note (owed to an ADR when the architecture phase begins).**
> - **Hand-rolled search, not the built-in pathfinder.** The depth-dependent edge cost **cannot** be
>   expressed with Redot/Godot's `AStarGrid2D`/`AStar2D`. The precise reason (not "static weights" —
>   `AStarGrid2D` *does* expose overridable `_compute_cost(from, to)`/`_estimate_cost(from, to)`): that
>   callback receives **only the two grid points**, with **no accumulated path depth / `g_score`
>   parameter**, so a cost that depends on `tiles_moved_this_turn` + steps-so-far cannot be computed
>   inside it without smuggling in external mutable state — which then breaks A*/Dijkstra's "a settled
>   node's cost is final" closed-set invariant (the same physical tile legitimately has different entry
>   costs on different-depth paths). Don't go looking for a weight-scale escape hatch; there isn't one
>   for depth-dependence. Implement over Grid's `neighbors()`/`is_passable()`/`occupant_at()` API.
> - **Valid shortcut under current (uniform-terrain) rules:** because per-tile cost is a pure function
>   of path **length**, the min-cost path is the min-**step** path — a plain **BFS** plus a closed-form
>   length→cost conversion is correct and cheaper than a full priority-queue Dijkstra. **This shortcut
>   breaks the moment `difficult-terrain` (Alpha Open Question) lands** — variable per-tile cost makes
>   a shorter path potentially more expensive, forcing a true `(tile, depth)`-keyed weighted search.
>   Revisit then; do not hardcode the length-monotonicity assumption as permanent.
> - **Fixed-point penalty, not float (defensive).** Represent `SOFT_MOVE_PENALTY` as a scaled integer
>   (e.g. `PENALTY_X10 = 20` for 2.0) and compute the surcharge as integer ceiling-division
>   `((move_cost × PENALTY_X10) + 9) / 10`. **Scope of the risk (narrower than "always overcharges"):**
>   GDScript `float` is a 64-bit double, and for `move_cost` 1–3 × penalty 1.5–3.0 the products are
>   small enough that most are exactly representable. The actual hazard is the **boundary case** — a
>   penalty × move_cost *designed* to be a whole number (e.g. any move_cost × 2.0, or move_cost 2 ×
>   1.5 = 3.0) landing a hair *below* the integer due to the decimal literal's binary representation,
>   making `ceil()` round up one AP too many. It won't fire across the whole range, only for those
>   near-integer products — but AP is an integer-correctness-critical resource (the Integer-AP
>   invariant), and this is a *live-tunable* knob, so fixed-point is the cheap insurance. *(Ownership:
>   `SOFT_MOVE_PENALTY` is Unit-owned; this representation change is flagged to Unit System / the spike.)*
> - **Deterministic structures:** back the search's visited/cost table with a flat
>   `index(x,y)=y*GRID_WIDTH+x` array (Grid already defines it), **not** a `Dictionary` — Godot
>   Dictionary iteration/sort order is not a guaranteed contract, and AI-clone parity needs a stable
>   order. Give the search an explicit state parameter (`reachable(state, unit)`, or a method on
>   `GameState`/`Grid`) so a cloned state can never read the authoritative grid by mistake.
> - **Perf budget (owed):** `reachable()` is recomputed per selection (no cache) and called by AI
>   lookahead over many cloned states; the AI Opponent GDD (or an ADR) should pin a concrete budget
>   (e.g. `reachable()` ≤ X ms on 24×24; ≤ N calls per AI decision) for `performance-analyst` to profile.
>   The eventual ADR should also pin the visited/cost-array **allocation strategy** (fresh-per-call —
>   simplest, GC/alloc cost — vs. pooled-and-cleared across AI lookahead calls — faster but needs
>   explicit clear-to-avoid-stale-across-clones discipline), since it directly shapes that budget.
> - **Grid API not yet pinned (cross-doc dependency).** This search couples to Grid's
>   `neighbors()` / `is_passable()` / `occupant_at()` — exact signatures **not yet specified** in the
>   Grid & Terrain GDD or any ADR. Those three method contracts must land there before Movement's
>   search can be coded. Blocking for *implementation*, not for this design doc.

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
summation, `ceil` rule, and depth-dependent reachability) is Movement-owned and was
**`/design-review`-confirmed sound on 2026-07-21** (the numbers stay spike-gated; only the formula and
spec are approved).

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
- **Surcharge legibility (Pillar 3 — required, NOT a watch-item):** the reachable overlay must
  **visually distinguish in-cap (base-cost) tiles from over-cap (surcharged) tiles**, and must reflect
  the unit's **current** `tiles_moved_this_turn`. Because the counter is cumulative but the overlay is
  recomputed per selection, a partially-moved unit's cheap zone *shrinks* when it is reselected mid-turn
  — that change must be **shown on the board**, never something the player has to track mentally (the
  exact hidden-state Pillar 3 forbids). Owned by the Command & Action Interface (#9); stated here as a
  hard requirement because it is the readability cost the depth-dependent formula introduces. *(This
  supersedes the earlier "spike/UX watch item" framing in Open Questions.)*
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

- **GIVEN** a Scout (`move_cost` 1, `soft_move_cap` 4, `SOFT_MOVE_PENALTY` 2.0) with 5 AP on open
  terrain, **WHEN** `reachable` is computed, **THEN** exactly the empty passable tiles within a
  **4-step** traversable path are returned (tiles 1–4 cost 1 AP each, within cap); **no 5-step-only
  tile is included** — the 5th tile would cost `ceil(1×2.0)` = 2 AP, exceeding the remaining 1 AP.
  *(Matches the Formulas worked example; the pre-revision uniform-cost answer of 5 tiles no longer
  holds.)*
- **GIVEN** a **fresh** Trooper (`move_cost` 2, `tiles_moved_this_turn` 0) with 5 AP, **WHEN** it
  moves a 2-tile path, **THEN** exactly 4 AP are spent (1 remains).
- **GIVEN** a **separate fresh** Trooper (`tiles_moved_this_turn` 0, `soft_move_cap` 3) with 5 AP,
  **WHEN** a 3-tile path is considered, **THEN** its cost is exactly 6 AP (3 in-cap tiles × 2) and it
  is **not offered** — excluded from `reachable()`'s returned set **and** rejected by `move()` if
  attempted directly (fails `can_afford`). *(Split from the old combined AC to remove the
  fresh-vs-sequential ambiguity: this is a fresh unit, not the same Trooper after its first move.)*
- **GIVEN** a friendly unit between the mover and an empty tile, **WHEN** `reachable` is computed,
  **THEN** the empty tile beyond is reachable (the mover paths through the friendly).
- **GIVEN** an **enemy unit** between the mover and a tile, **WHEN** `reachable` is computed, **THEN**
  the path is blocked there and tiles reachable only through it are excluded.
- **GIVEN** a **friendly *structure*** (HQ/outpost, mover's own owner) between the mover and a tile,
  **WHEN** `reachable` is computed, **THEN** it **blocks** (tiles reachable only through it are
  excluded) — proving the pass-through rule applies to friendly **units only**, never friendly
  structures. *(Split from the old combined enemy-or-structure AC; the "friendly units pass through
  but friendly structures do not" distinction is the easiest blocker rule to implement wrong, so it
  gets its own explicit test.)*
- **GIVEN** a friendly-occupied tile, **WHEN** it is considered as a destination, **THEN** it is not
  a valid stop (`move` to it is rejected); an Impassable tile is likewise never a valid stop.
- **GIVEN** a unit adjacent to an enemy, **WHEN** it moves past/around the enemy, **THEN** it is not
  stopped or slowed (no zone of control in the VS).
- **GIVEN** a unit with AP remaining after a move, **WHEN** it moves again, **THEN** the second move
  is allowed and charged normally (AP-gated only).
- **GIVEN** a Heavy (`move_cost` 3, `soft_move_cap` 2, `tiles_moved_this_turn` 0,
  `SOFT_MOVE_PENALTY` 2.0) with sufficient AP, **WHEN** it moves a 3-tile path, **THEN** the total
  cost is exactly **12 AP** (2 in-cap tiles × 3 + 1 over-cap tile × `ceil(3×2.0)` = 6 + 6); the
  over-cap tile costs `ceil(move_cost × SOFT_MOVE_PENALTY)`, not `move_cost`.
- **GIVEN** a Scout (`move_cost` 1, `soft_move_cap` 4, `SOFT_MOVE_PENALTY` 2.0,
  `tiles_moved_this_turn` 0), **WHEN** it moves 6 tiles as **one** `move()` call vs. **two** calls of
  3 + 3 (a split that **crosses the cap**), **THEN** both charge exactly **8 AP** (4 in-cap × 1 +
  2 over-cap × `ceil(1×2.0)`) — the cumulative counter prevents chunking from resetting the cheap
  budget. *(The split must straddle the cap; a wholly in-cap split would pass trivially and prove
  nothing.)*
- **GIVEN** a Scout (`move_cost` 1) at `SOFT_MOVE_PENALTY` **1.5** with
  `tiles_moved_this_turn` ≥ `soft_move_cap`, **WHEN** it enters one further (over-cap) tile, **THEN**
  the charge is `ceil(1×1.5)` = **2 AP** (not 1.5, not 1) and the total AP spent is an integer.
- **GIVEN** a destination tile T returned by `reachable(unit)` at reported cost X — **including at
  least one case where X reflects one or more over-cap tiles** — **WHEN** `move(unit, T)` is executed,
  **THEN** the AP actually spent equals X **exactly** (the reachable-vs-billed agreement invariant in
  Formulas; the two share one soft-cap-aware summation by construction). This must hold on the
  authoritative state and any `clone()`.
- **GIVEN** the same grid state and unit — **including a mid-turn clone where
  `tiles_moved_this_turn` > 0** (so the depth-dependent surcharge is actually exercised) — **WHEN**
  `reachable` is computed twice, **THEN** the results are identical (determinism; headless-computable).
- **GIVEN** a grid state with **two or more equal-cost paths** to the same destination tile T, **WHEN**
  `move(unit, T)` is executed twice from the identical starting state, **THEN** the **identical tile
  sequence** is chosen both times (tie-break path selection is deterministic — pins Rule 8's "stable
  iteration order" for replay/animation/AI-clone parity, which the reachable-set-identity AC above does
  **not** cover — that one only checks *which tiles* are reachable, not *which path* is walked).
  *(Integration-type → `tests/integration/movement/`; exercises the search's neighbor-expansion order,
  which must be a pinned, reproducible order, not hash/insertion-dependent.)*
- **GIVEN** a unit for which `reachable()` has been computed with a blocking enemy/structure in the
  way, **AND** that blocker is subsequently removed from the grid (e.g. destroyed in combat) **with no
  other state change**, **WHEN** `reachable()` is computed again, **THEN** the newly-opened tiles are
  included — proving reachability is recomputed **fresh from current state each time (no stale cache)**,
  per the Edge Cases "board changes mid-turn" rule. *(Integration-type → `tests/integration/movement/`;
  guards the classic caching bug the no-cache rule exists to prevent.)*
- **GIVEN** a unit whose `move_cost` exceeds `current_ap`, **WHEN** `reachable` is computed, **THEN**
  it returns the empty set.
- **GIVEN** a Heavy already at/past its cap (`tiles_moved_this_turn` ≥ `soft_move_cap` 2) with
  `current_ap` = 4, **WHEN** `reachable` is computed, **THEN** it returns the **empty set** — the next
  tile costs `ceil(3×2.0)` = 6 AP > 4, **even though the base `move_cost` 3 alone would be
  affordable**. *(A distinct boundary from the `move_cost > current_ap` empty-set case above: here the
  base cost fits but the surcharge does not.)*

## Open Questions

| Question | Owner | Notes / target |
|----------|-------|----------------|
| Difficult terrain (variable per-tile move cost — e.g. slow tiles, high ground)? | Movement / Grid | Deferred to Alpha; Grid flagged this and Movement owns the mechanic |
| Zone of control (adjacent enemies stop/slow movement)? | game-designer | VS = OFF; ZoC adds tactical depth but complicates readability (Pillar 3) — Alpha |
| Should friendly *structures* be pass-through too, or only friendly units? | game-designer | This GDD sets: only friendly **units** are pass-through; all structures block. **CONFIRMED in the 2026-07-21 re-review** — dedicated AC added (friendly structure blocks). Closed. |
| Overwatch / reaction moves (a unit reacting during the enemy turn)? | Combat / game-designer | Out of VS scope; would break the strict turn model — Alpha+ |
| Ranged kiting emerges from these rules (no ZoC + no overwatch + multiple AP-gated moves + move-then-attack lets a ranged unit move → shoot → retreat freely). | **game-designer** (design call) — **Movement (#5)** owns any *movement-side* lever, **Combat (#6)** owns any *attack-side* lever; decided in the ranged-combat spike | Watch item — the cross-cutting RANGED-COMBAT decision flags kiting (esp. Sniper, range 3 / `move_cost` 2) as the highest-risk *unvalidated* behavior. Movement is half of what enables it. **Note: the soft-cap surcharge (added 2026-07-20) does NOT tax kiting** — a 1–2 tile standoff kite sits under every unit's `soft_move_cap`; the surcharge only brakes deep single-turn over-extension/rushes. **Named fallback (no longer a bare TBD):** *if the combat spike confirms degenerate kiting,* the fix is a **separate** anti-kite lever — the candidates are **partial Zone-of-Control** (Movement-owned) or a **move-then-attack AP cost / restriction** (Combat-owned) — **not** a lower soft cap and **not** stretching the surcharge to cover it. game-designer picks the lever from spike data; this row names the owners so the three docs stop each assuming another owns the fix. Mirrors unit-system.md's Sniper "no-counter" spike hypothesis. |
| Does the depth-dependent reachability cost (soft-cap surcharge) hurt reachable-set compute cost or preview clarity? | Movement / Command & Action Interface | **Preview-clarity half RESOLVED (2026-07-20 re-review):** promoted from watch-item to a hard overlay requirement (in-cap vs over-cap tiles visually distinct; overlay reflects current `tiles_moved_this_turn`) — see Visual/Audio Requirements. **Compute-cost half:** search stays monotonic (BFS/Dijkstra) but no longer uniform — a concrete `reachable()` perf budget for AI lookahead is owed to the AI Opponent GDD / an ADR (see Formulas implementation note). |
