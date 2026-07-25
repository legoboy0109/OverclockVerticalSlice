# Epic: Grid & Terrain

> **Layer**: Foundation
> **GDD**: design/gdd/grid-terrain.md
> **Architecture Module**: Grid & Terrain
> **Status**: Ready
> **Stories**: 4 stories created — see table below

## Overview

Grid & Terrain is the spatial foundation of OVERCLOCK: a fixed-size rectangular board (14×16
for the Vertical Slice) of square tiles holding two things — positional state (occupancy: what
occupies each tile) and terrain properties (Plain / Cover / Impassable). It exposes a
deterministic, render-decoupled query/mutation API (`in_bounds`, `terrain_at`, `is_cover`,
`occupant_at`, `is_passable`, `neighbors`, `manhattan_distance`, `place`, `remove`, `move`) that
every other gameplay system builds against. The authoritative grid — flat `PackedByteArray`
terrain + `PackedInt32Array` occupancy, both indexed `y*W+x` (ADR-0005) — is a plain data model
independent of the on-screen `TileMapLayer`, so the AI can evaluate hypothetical board states and
the test suite can run headless. This epic also covers the load-time HQ-to-HQ reachability
validator and the two map-authoring modes (Authored / Procedural Center).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0005: Grid representation & map format | `GridState extends Resource`; flat `PackedByteArray` terrain + `PackedInt32Array` occupancy (entity_id or -1), both indexed `y*W+x`; `MapDefinition` Resource (.tres) with Authored/Procedural modes; `build_grid()` sole constructor; BFS HQ-reachability validator (Authored rejects, Procedural self-corrects by seed-stable thinning) | LOW |
| ADR-0001: State model ownership & lifecycle | Grid model is decoupled from render nodes (pure GDScript `Resource`, not `Node`) and lives inside `GameState` as authoritative data | MEDIUM (`duplicate_deep()`, Godot 4.5) |
| ADR-0011: AI opponent decision loop | Grid's read API (`manhattan_distance`, `terrain_at`, `occupant_at`) must support many AI positional queries per turn, side-effect-free and O(1)/O(4) | LOW |
| ADR-0013: Isometric board rendering, picking & overlays | Board Renderer (Presentation layer) reads the grid via `grid_to_screen`/`screen_to_grid` for the 2:1 dimetric projection and inverse hit-testing — Grid itself is never mutated by this, and never uses engine `local_to_map()` (GH#89423 bug) | HIGH — pre-Accept engine spike **PASS 2026-07-25** (diamond tiling seamless, `y_sort_enabled` draw-order correct) |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-grid-001 | Fixed-size 2D tile grid, integer (x,y), origin top-left, no wrap; dims 8x8-24x24 (VS 14x16), flat 1D array index=y*W+x | ADR-0005 ✅ |
| TR-grid-002 | One terrain type per tile {Plain,Cover,Impassable}, static post-load; passable-set cacheable once | ADR-0005 ✅ |
| TR-grid-003 | Occupancy map (tile->entity id/none) separate from terrain, single-occupant invariant, atomic within resolution step | ADR-0005 ✅ |
| TR-grid-004 | Deterministic render-decoupled API: in_bounds, terrain_at, is_cover, occupant_at, is_passable, neighbors, manhattan_distance, place, remove, move | ADR-0005 ✅ |
| TR-grid-005 | Grid model decoupled from render node; no query depends on frame timing/TileMapLayer; pure GDScript class/Resource not Node | ADR-0001 ✅ |
| TR-grid-006 | Grid model is part of authoritative state owned by Game State & Turn Manager | ADR-0001 ✅ |
| TR-grid-007 | All queries O(1) except neighbors O(4); manhattan_distance/in_bounds integer arithmetic (high-volume AI+Movement calls) | ADR-0005 ✅ |
| TR-grid-008 | ISO: render-side projection layer (TileMapLayer) reads grid; grid->screen 2:1 dimetric transform, inverse picking, depth-sort separate from logical grid | ADR-0013 ✅ (implemented by the Board Renderer epic, Presentation layer — Grid exposes only read queries) |
| TR-grid-009 | Deterministic seeded procedural terrain byte-identical per seed+config; seeded PRNG (PROC_SEED) not engine global RNG (also ADR-0003 Rule 1) | ADR-0005 ✅ |
| TR-grid-010 | Load-time HQ-to-HQ reachability validator (BFS flood-fill over passable); Procedural self-corrects, Authored hard-rejects | ADR-0005 ✅ |
| TR-grid-011 | Two map modes (Authored / Procedural Center) per map def with band-placement constraints and PROC_* params | ADR-0005 ✅ |
| TR-grid-012 | Reject/guard invalid maps at load (dims, HQ unreachable, density) with deterministic fallback (density clamp + log) | ADR-0005 ✅ |
| TR-grid-013 | Serialize map definition sufficient to reconstruct identical grid; map defs are data assets (.tres/JSON) | ADR-0005 ✅ |
| TR-grid-014 | Expose read-only tile-highlight data (terrain, occupancy, cover, passability) to UI without mutation | ADR-0005 ✅ |
| TR-grid-015 | Support AI positional queries many times/turn without mutating shared state; side-effect-free, O(1) | ADR-0011 ✅ (consumed by the AI Opponent epic — Grid supplies the read API) |

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | GridState Core Data Model & Read Query API | Logic | Complete | ADR-0005 |
| 002 | Grid Mutation API — place/remove/move & Single-Occupant Invariant | Logic | Ready | ADR-0005 |
| 003 | MapDefinition & Authored Build Pipeline | Logic | Ready | ADR-0005 |
| 004 | Procedural Center Terrain Generation & Self-Correcting Reachability | Logic | Ready | ADR-0005 |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/grid-terrain.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/story-readiness production/epics/grid-terrain/story-001-gridstate-core-query-api.md` to begin implementation.
