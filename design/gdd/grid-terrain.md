# Grid & Terrain

> **Status**: Designed (user-approved 2026-07-19 — pending independent `/design-review`)
> **Author**: user + main session
> **Last Updated**: 2026-07-19
> **Implements Pillar**: Pillar 3 (Readable Board, Deep Decisions); enables Pillar 2 (Tempo Is the Skill via terrain depth)
> **Priority / Layer**: Vertical Slice / Foundation (system #1)

## Overview

Grid & Terrain is the spatial foundation of OVERCLOCK: a fixed-size rectangular board of
square tiles that holds two things — **positional state** (what occupies each tile) and
**terrain properties** (whether a tile is open, cover, or impassable). It is pure
infrastructure: players never manipulate the grid directly, but every unit, structure,
move, attack, and AP-costed decision is expressed in its coordinates. The system exposes a
deterministic query/mutation API (in-bounds tests, terrain lookup, occupancy, neighbors,
placement) that every other gameplay system builds against. Crucially, the authoritative
grid is a plain, render-decoupled data model — the on-screen `TileMapLayer` is only a view —
so the tempo AI can evaluate hypothetical board states and the test suite can run headless.

> **Projection note (2026-07-23):** The board renders in **2:1 isometric (dimetric)** projection
> — see `design/art/art-bible.md` (Map Projection Decision). This is a **view-layer** choice only:
> every rule, coordinate, adjacency, and distance in this GDD is computed in **logical grid space**
> and is projection-invariant. "Square tiles" below means square *in grid space*; they render as
> 2:1 diamonds. "Cardinal / 4-directional (N/S/E/W)" means the four **grid** axes — under isometric
> these render along the screen *diagonals*, but adjacency and all grid math are unchanged. The
> isometric view introduces new *architecture* concerns (grid→screen transform, inverse mouse→tile
> picking, depth-sort, iso overlay rendering) captured in
> `docs/architecture/change-impact-2026-07-23-isometric-projection.md` — none alter this GDD's rules.

## Player Fantasy

Grid & Terrain is infrastructure — players don't "feel" the grid, they feel *what it
enables*: a board they can read at a glance and reason about completely. The fantasy it
serves is the **clarity that makes deep decisions possible** (Pillar 3). Because the grid is
discrete, finite, and fully visible — no fog, no hidden information, no diagonal ambiguity —
the player can always see the whole tactical situation and knows that any outcome is a
consequence of their reasoning, never of concealed state or luck. Terrain (cover,
chokepoints) is where the grid quietly adds tactical texture: the player starts to *see*
positions, not just tiles. The grid should be invisible as a system and indispensable as a
stage.

## Detailed Rules

### Core Rules

1. **The board is a rectangular grid** of `GRID_WIDTH` × `GRID_HEIGHT` square tiles.
   The engine supports any dimensions in the **8×8 to 24×24** range (this stays the accepted
   bound for the future map editor / map variety). **The Vertical Slice ships a single pinned
   board size: `GRID_WIDTH` = 14, `GRID_HEIGHT` = 16** (decision 2026-07-22 — see Tuning Knobs
   and the dominant-strategy resolution note). Prototype baseline was 8×8; variable per-map sizes
   are an Alpha/map-editor goal, deliberately out of VS scope.
   Larger maps trade maneuver room for longer matches and heavier AI/movement search.
2. **Coordinates are integer `(x, y)`**, origin top-left `(0,0)`, where `x` is the column
   (`0 … GRID_WIDTH−1`) and `y` is the row (`0 … GRID_HEIGHT−1`). No wrap-around.
3. **Adjacency is 4-directional (orthogonal / von Neumann)**: a tile's neighbors are the
   tiles directly N/S/E/W. Diagonals are never adjacent. This is fixed for the Vertical
   Slice (it keeps the board readable — Pillar 3 — and matches the prototype).
4. **Each tile has exactly one terrain type** from the Vertical-Slice set:
   - **Plain** — passable, no combat modifier. The default.
   - **Cover** — passable; grants a defensive damage reduction to a **unit** occupant *(magnitude
     owned by the Combat GDD, which also scopes application — structures are cover-immune; Grid owns
     only the "this tile is cover" flag)*.
   - **Impassable** — never passable, never occupiable (walls, chasms, void). Creates
     chokepoints and defensible shape.
5. **Occupancy: each tile holds at most one occupant** (a unit, an HQ, or an outpost) or is
   empty. The grid owns the occupancy map (tile → entity id). Impassable tiles are never
   occupiable.
6. **A tile is passable-for-movement** iff its terrain ≠ Impassable **and** it is currently
   empty. (Movement-through-friendly-units is handled by the Movement GDD as a pathing rule;
   the *destination* tile must still be empty to stop on.)
7. **The authoritative grid is a deterministic in-memory model**, decoupled from rendering.
   Building the same map definition twice yields identical grids; no query depends on frame
   timing, RNG, or render state.
8. **Terrain is established once at map load** — either hand-**Authored** (terrain placed
   per tile) or **Procedurally Generated** (see below) — and is then **static** for the
   entire match. No terrain changes during play in the Vertical Slice.

### Procedural Center Terrain (optional map mode)

A map may be built in one of two modes: **Authored** (hand-placed terrain) or **Procedural
Center**, which scatters Cover and/or Impassable terrain across a central band of the board
to force contested engagements and break up open-field play.

**Rules:**
1. Generation runs **exactly once at map load, from an explicit integer seed** (`PROC_SEED`).
   Same seed + same config → **byte-identical** map. Generation is therefore fully
   deterministic and headless-reproducible. *(This does not violate the "no randomized
   outcomes" anti-pillar — that governs combat resolution during play; map construction is a
   pre-match, seeded, one-time step, like choosing a starting board.)*
2. Features are placed only within a **central band** — a strip of `PROC_BAND_WIDTH` tiles
   centered on the board, oriented perpendicular to the HQ-to-HQ axis — so both sides face
   the same contested middle. HQ tiles and their immediate deploy area are never overwritten.
3. `PROC_DENSITY` (0.0–1.0) sets the fraction of band tiles that receive a feature;
   `PROC_FEATURE_MIX` sets the Cover-vs-Impassable split (e.g. 0.7 = 70% Cover, 30% Impassable).
4. `PROC_SYMMETRIC` (default **true**): the generated layout is mirrored across the board's
   center so neither side gets a positional advantage — important for a fair competitive duel.
5. **Reachability guarantee:** the generator must never wall off the two HQs from each other.
   If a candidate layout fails the HQ-to-HQ passability check (see Edge Cases), the generator
   applies **one deterministic correction**: it removes Impassable features from the band in a
   fixed, seed-stable order (thinning density) and re-tests, repeating until both HQs are
   mutually reachable. Thinning always terminates (removing all Impassable features guarantees
   reachability). There is **no re-roll** — the correction is a pure function of the failed
   layout, so the same seed + config always yields the same corrected map.

### States and Transitions

Terrain is **static** (set at map load, never changes during a match in the Vertical Slice).
The only dynamic per-tile state is **occupancy**:

| Tile state | Meaning | Transitions to |
|------------|---------|----------------|
| Empty | No occupant; passable if not Impassable | Occupied (on `place`/`move` into it) |
| Occupied(entity) | Holds exactly one entity | Empty (on `remove`/`move` out, or occupant destroyed) |
| Impassable | Structural — never Empty, never Occupied | (none — immutable for the match) |

Single-occupant invariant: no transition may place a second entity on an already-Occupied
tile; such an attempt fails deterministically and leaves state unchanged (see Edge Cases).

### Interactions with Other Systems

| System | Data flowing in | Data flowing out | Interface owner |
|--------|-----------------|------------------|-----------------|
| Game State & Turn Manager | — | The grid model is part of the authoritative game state it holds | Game State |
| Unit System | place/remove/move requests | occupancy updates, position of each unit | Grid (mutation API) |
| Base & Production | place structure (HQ/outpost) on a chosen tile | placement success/failure; occupancy | Grid (mutation API) |
| Movement System | passability + neighbor queries | passable set, adjacency for pathfinding | Grid (query API) |
| Combat Resolution | terrain cover flag + adjacency query | is-cover, are-adjacent | Grid (query API) |
| Command & Action Interface / HUD | terrain + occupancy | tile grid to render + highlight overlays | Grid (read API) |

**Grid API (the contract downstream systems build against):**
`in_bounds(x,y)` · `terrain_at(x,y)` · `is_cover(x,y)` · `occupant_at(x,y)` ·
`is_passable(x,y)` · `neighbors(x,y)` · `manhattan_distance(a,b)` ·
`place(entity, x,y)` · `remove(x,y)` · `move(from, to)`.

## Formulas

Grid & Terrain has no *balance* formulas — its math is definitional. All are integer,
deterministic, and O(1) except `neighbors` (O(4)).

**In-bounds test:**

`in_bounds(x, y) = (0 ≤ x < GRID_WIDTH) AND (0 ≤ y < GRID_HEIGHT)`

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| x, y | int | any | Candidate cell coordinate |
| GRID_WIDTH, GRID_HEIGHT | int | 8–24 engine; VS pinned 14×16 | Board dimensions (per-map) |

**Output:** boolean. **Example:** on an 8×8 grid, `in_bounds(7,7)=true`, `in_bounds(8,0)=false`.

**Flat storage index** (if grid is stored as a 1D array):

`index(x, y) = y * GRID_WIDTH + x`

**Output range:** `0 … GRID_WIDTH*GRID_HEIGHT − 1`. **Example:** on 8×8, `index(3,2) = 2*8+3 = 19`.

**Orthogonal neighbors:**

`neighbors(x, y) = { (x+1,y), (x−1,y), (x,y+1), (x,y−1) } filtered by in_bounds`

**Output range:** 2 tiles (corner) to 4 tiles (interior). Never returns out-of-bounds tiles.
**Example:** `neighbors(0,0) = {(1,0),(0,1)}` (2); `neighbors(3,3)` on 8×8 = 4 tiles.

**Manhattan distance** (used by Movement/Combat for range and adjacency):

`manhattan_distance((x1,y1),(x2,y2)) = |x1−x2| + |y1−y2|`

**Output range:** `0 … (GRID_WIDTH−1)+(GRID_HEIGHT−1)`. **Example:** `(0,0)→(2,3) = 2+3 = 5`.
Adjacency is the special case `manhattan_distance == 1`.

> The **cover damage reduction magnitude** is NOT defined here — Grid owns the *flag*
> (`is_cover`), Combat Resolution owns the *effect*. Prototype baseline was −1; the final
> value lives in the Combat GDD's Formulas section.

## Edge Cases

- **If a coordinate is queried out of bounds**: all queries treat it as invalid —
  `in_bounds` returns false, `terrain_at`/`occupant_at` return a null/none sentinel,
  `neighbors` excludes it. No wrap-around, ever.
- **If `place` targets an already-Occupied tile**: the placement is **rejected** (returns
  failure); the existing occupant is unchanged. Callers must check `is_passable`/`occupant_at`
  first. This enforces the single-occupant invariant.
- **If `place` or a movement destination targets an Impassable tile**: rejected; Impassable
  tiles are never occupiable.
- **If `remove` targets an Empty or Impassable tile**: no-op (idempotent); returns failure/none.
- **If two placements target the same Empty tile in the same resolution step**: resolved in
  deterministic call order — the first succeeds, the second is rejected. No simultaneous
  co-occupancy is possible.
- **If an occupant is destroyed** (by Combat): its tile transitions to Empty immediately, in
  the same resolution step, so subsequent queries that step see it as free.
- **If `GRID_WIDTH` or `GRID_HEIGHT` < 8 or > 24**: map is invalid — reject at load
  (below-8 has no room for tactics; above-24 is out of VS scope — readability, match length,
  and AI-search cost all degrade beyond it).
- **If a map's terrain (authored or generated) fully walls off one HQ from the other**:
  flagged at map-load validation — both HQs must be mutually reachable across passable tiles.
  For **Procedural Center** maps the generator self-corrects (thins Impassable density) rather
  than producing an invalid map. This is a load-time check, not a runtime state.
- **If Procedural Center generation is asked to place features on HQ or deploy tiles**: those
  tiles are excluded from the candidate set — generation never overwrites an HQ or its
  immediate deploy area.
- **If `PROC_DENSITY` is set so high that even a thinned layout can't keep the HQs connected**
  (e.g. a full Impassable wall band): the generator falls back to the maximum density that
  still guarantees reachability and logs the clamp — it never emits an unplayable map.
- **If `PROC_BAND_WIDTH` ≥ the board's smaller dimension**: clamp the band to the board and
  treat it as "whole-board scatter"; still honor the HQ/deploy exclusions and reachability.

## Dependencies

**Upstream (this system depends on):** None — Grid & Terrain is a true Foundation system
(engine primitives only: `Vector2i`, `TileMapLayer` for rendering).

**Downstream (systems that depend on this — all HARD dependencies):**

| Dependent system | Nature | What it needs from Grid |
|------------------|--------|-------------------------|
| Game State & Turn Manager | Hard | Holds the grid as part of authoritative state; determinism guarantees |
| Unit System | Hard | Position storage; place/remove/move |
| Movement System | Hard | `is_passable`, `neighbors`, `manhattan_distance` for reachable-tile search |
| Combat Resolution | Hard | `is_cover`, adjacency (`manhattan_distance == 1`) for target validation |
| Base & Production | Hard | `place` structures on chosen tiles; occupancy checks for deploy-tile selection |
| Command & Action Interface / Game HUD | Hard | Read terrain + occupancy to render board and highlight overlays |
| AI Opponent | Hard | `manhattan_distance`, `terrain_at`, `occupant_at` — positional inputs to scoring |

*Bidirectional note:* each dependent GDD, when authored, must list Grid & Terrain under its
own Dependencies section.

## Tuning Knobs

| Knob | VS Range | Default | Affects | If too high | If too low |
|------|----------|---------|---------|-------------|------------|
| `GRID_WIDTH` × `GRID_HEIGHT` | 8×8 – 24×24 (engine); **VS pinned to 14×16** | **14×16 (VS)** | Match length, maneuver room, readability | Sprawling matches, readability strain at 1080p, slower AI/movement search | Cramped board, no maneuvering, tempo swings feel forced |
| Terrain type set | {Plain, Cover, Impassable} | (all three) | Tactical texture | Cognitive overload (Pillar 3 risk) | Flat, featureless board |
| Per-map terrain layout | Authored or Procedural Center | authored | Chokepoints, defensibility, pacing | Over-walled → stalemates | Open field → no positional play |
| Adjacency mode | 4-dir (fixed VS) | 4-directional | Movement/combat reach | (8-dir would blur readability + rebalance everything) | — |
| `PROC_SEED` | any int | per-map | Which procedural layout is produced (deterministic) | — | — |
| `PROC_BAND_WIDTH` | 1 – min(W,H) tiles | ~⅓ of the axis | Size of the contested center strip | Whole board becomes obstacle field | Thin band → easy to skirt, little effect |
| `PROC_DENSITY` | 0.0 – 1.0 | 0.3 | Fraction of band tiles with a feature | Chokey/stalematey; auto-clamped for reachability | Sparse, negligible effect |
| `PROC_FEATURE_MIX` | 0.0 – 1.0 (Cover share) | 0.7 | Cover-vs-Impassable ratio in the band | Mostly cover → soft, passable | Mostly walls → hard chokepoints, stalemate risk |
| `PROC_SYMMETRIC` | bool | true | Mirror layout for fairness | — | Asymmetric center → one side may be favored (avoid in competitive maps) |

> Grid dimensions and terrain layout are **per-map data**, authored in level design — not
> global constants. Only the *ranges/defaults* above are project-level knobs.

## Visual/Audio Requirements

Grid & Terrain is Foundation infrastructure, but it carries the board's readability, which is
Pillar 3's whole point. Anchored to the **Neon Retro-Future** visual identity (esp. Principle
3, *dark stage, neon actors*):

- **Terrain must recede.** Plain tiles are muted dark neutrals; the grid reads as a quiet
  stage so neon units/structures pop. If terrain competes with units for attention, dim it.
- **Cover tiles are visually distinct but subordinate** — a subtle pattern/tint that a player
  can spot without it shouting over unit colors.
- **Impassable tiles read unambiguously as "you cannot go here"** (solid/wall treatment),
  distinct from cover at a glance.
- **Grid lines** are subtle — enough to count tiles, not enough to add visual noise.
- Audio: none intrinsic to the grid (feedback SFX belong to Movement/Combat/UI).

> 📌 **Asset Spec** — Visual requirements are defined. After the art bible is approved, run
> `/asset-spec system:grid-terrain` to produce per-asset tile specs, dimensions, and
> generation prompts from this section.

## UI Requirements

The grid must support **tile-highlight overlays** driven by the Command & Action Interface:
reachable-move tiles, valid attack targets, valid deploy tiles, and a cover indicator. The
grid provides the tile geometry and read API; the *visual design and interaction flow* of
these overlays are owned by the Command & Action Interface GDD (#9), not here.

> 📌 **UX Flag — Grid & Terrain**: This system contributes tile-highlight overlays. In
> Phase 4 (Pre-Production), run `/ux-design` for the core gameplay HUD / action interface
> **before** writing epics; stories referencing highlight visuals should cite
> `design/ux/[screen].md`, not this GDD.

## Acceptance Criteria

- **GIVEN** an 8×8 grid, **WHEN** `in_bounds` is queried for `(0,0)` and `(7,7)`, **THEN**
  both return true; `(−1,0)` and `(8,0)` return false.
- **GIVEN** a tile authored as Cover, **WHEN** `terrain_at`/`is_cover` is queried, **THEN**
  it returns Cover / true — identically on every run (determinism).
- **GIVEN** an empty passable tile, **WHEN** an entity is placed, **THEN** `occupant_at`
  returns that entity and `is_passable` for that tile becomes false.
- **GIVEN** an Occupied tile, **WHEN** a second `place` is attempted, **THEN** it is rejected
  and the original occupant is unchanged.
- **GIVEN** an Impassable tile, **WHEN** `place` or a movement destination targets it,
  **THEN** it is rejected / excluded from the passable set.
- **GIVEN** an interior tile not on an edge, **WHEN** `neighbors` is requested, **THEN**
  exactly the 4 orthogonal in-bounds tiles are returned; a corner tile returns exactly 2,
  and no result is ever out of bounds.
- **GIVEN** tiles `(0,0)` and `(2,3)`, **WHEN** `manhattan_distance` is computed, **THEN**
  it returns 5; adjacent tiles return 1.
- **GIVEN** the same map definition, **WHEN** the grid is built twice, **THEN** both
  instances are identical (occupancy + terrain byte-for-byte).
- **GIVEN** a Procedural Center map with a fixed `PROC_SEED` and config, **WHEN** the map is
  generated twice, **THEN** the two terrain layouts are byte-identical (seeded determinism).
- **GIVEN** a Procedural Center map with `PROC_SYMMETRIC = true`, **WHEN** it is generated,
  **THEN** the layout is mirror-symmetric across the board center, and both HQs remain
  mutually reachable across passable tiles.
- **GIVEN** a Procedural Center config whose density would wall off the HQs, **WHEN** the map
  is generated, **THEN** the generator clamps density to preserve HQ-to-HQ reachability and
  never emits an unplayable map.
- **GIVEN** a headless test run with no rendering node, **WHEN** the grid model is
  instantiated and queried, **THEN** all queries function correctly (render-decoupled).
- **GIVEN** a map that walls off one HQ from the other, **WHEN** the map is loaded, **THEN**
  load-time validation rejects it (HQs must be mutually reachable).

## Open Questions

| Question | Owner | Notes / target |
|----------|-------|----------------|
| ~~Final Vertical-Slice grid dimensions per map (8×8 baseline vs larger)?~~ **RESOLVED 2026-07-22** | game-designer / level design | **VS pinned to a single 14×16 board.** Chosen to defuse the map-size dominant-strategy composition (see AP Economy #3's resolved "Bimodal meta" open question): a fixed mid-small board keeps rush's punish window landing while the boom economy is still mid-tier, not post-ceiling. Corner-to-corner Manhattan distance = 28 tiles; sits just past the modeled 12–14-square band (22–26) but still lands rush contact ~turn 5–6 before boom is unrecoverable — a starting point to balance/playtest from. Variable map sizes + editor deferred to Alpha. |
| Add variable-move-cost terrain (difficult terrain, high ground) in Alpha? | Movement GDD author | Deferred — Movement GDD may want terrain that costs extra AP to enter |
| Can Impassable chokepoints help mitigate the endgame closeout-drag (defensible positions reduce corner-spam)? | Base & Production GDD author | Flag for #7 and level design — a spatial lever on the drag problem |
| Should cover be binary or have degrees (light/heavy cover)? | Combat GDD author | VS = binary; degrees are an Alpha consideration owned by Combat |
| Band orientation when HQs are corner-placed (diagonal axis) vs edge-placed — which axis is "center"? | game-designer / level design | VS assumption: band is perpendicular to the straight HQ-to-HQ axis; corner-diagonal maps may want a diagonal band |
| Should `PROC_DENSITY`/`PROC_FEATURE_MIX` scale with grid size so 24×24 maps aren't sparse? | systems-designer | Likely yes (density as fraction already scales); confirm feel on large maps during playtest |
| Does Impassable-as-sightline-blocker (from the cross-cutting RANGED-COMBAT decision) make Procedural-Center bands too strong? | game-designer / Combat / Grid | Watch item — Grid owns Impassable, which now doubles as a *line-of-fire* blocker, not just a movement chokepoint. `PROC_DENSITY`/`PROC_FEATURE_MIX` may need re-tuning once sightline-blocking is validated in the vertical slice / combat spike. Unit System raises the same flag. |
