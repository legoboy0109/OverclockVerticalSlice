# Epic: Movement

> **Layer**: Core
> **GDD**: design/gdd/movement-system.md
> **Architecture Module**: Movement (Core Layer)
> **Status**: Complete — all 3 stories implemented, reviewed, and closed (2026-07-26)
> **Stories**: 3 stories created (3 Complete)

## Overview

Movement owns the reachable-search algorithm and the movement verb: given a unit
and the current state, it computes the set of tiles the unit can legally reach
this turn (`reachable(state, unit) → {tile, min_cost, is_surcharged}`) and
resolves a committed move (`move(unit, dest) → Result`). It is a hand-rolled BFS
over a visited/cost flat array — deliberately **not** Godot's `AStarGrid2D` —
reading Grid passability/occupancy and Unit move costs, and spending AP through
the economy. Every mutation flows through `apply_action`; the search is pure,
integer-only, and deterministic (stable tile order).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0009: Reachable search / pathfinding | Hand-rolled BFS over flat visited/cost arrays; `reachable()` returns tile + min_cost + is_surcharged; no `AStarGrid2D` | LOW *(QQ-05 CLEARED 2026-07-25 — PASS, ~2.0ms/call worst-case; ADR-0009 Accepted 2026-07-25)* |
| ADR-0003: Deterministic simulation | Integer-only cost math; stable iteration; no engine RNG | LOW |
| ADR-0007: Entity/stat schema | Reads unit move-cost fields | MEDIUM (shared) |
| ADR-0002: apply_action | `move()` commits atomically via the pipeline | LOW |

## GDD Requirements

All 14 requirements are ADR-traced (0 untraced). Full requirement text in
`docs/architecture/tr-registry.yaml`.

| Governing ADR | TR-IDs | Coverage |
|---------------|--------|----------|
| ADR-0009 (reachable) | TR-movement-001, -002, -003, -004, -005, -008, -009, -010, -013 | ✅ |
| ADR-0003 (determinism) | TR-movement-006, -007, -011 | ✅ |
| ADR-0007 (unit stats) | TR-movement-012 | ✅ |
| ADR-0002 (apply_action) | TR-movement-014 | ✅ |

**Untraced Requirements**: None. **Note**: TR-movement-012 (schema enforces `move_cost >= 1`,
`soft_move_cap >= 0` at load) is governed by ADR-0007 and owned by Unit System, not this epic —
no Movement story implements it. No existing Unit System story currently enforces it either
(flagged as a Unit System backlog gap, not a Movement blocker).

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Reachable-Tile Search (`Movement.reachable()`) | Logic | Complete | ADR-0009 |
| 002 | Committed Move (`Movement.move()` / `MoveAction`) | Logic | Complete | ADR-0009 |
| 003 | Movement Determinism & No-Stale-Cache Guarantees | Integration | Complete | ADR-0009 |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/movement-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- The QQ-05 reachable/pathfinding perf spike (Sprint 2 S2-03) has a PROCEED verdict before movement stories are estimated/committed — **DONE**: QQ-05 concluded 2026-07-25 with a PASS verdict (`prototypes/qq05-reachable-bench/README.md`); ADR-0009 Accepted the same day.

## Next Step

Run `/story-readiness production/epics/movement/story-001-reachable-tile-search.md` then
`/dev-story` to begin implementation. Story order: 001 → 002 → 003 (each depends on the
previous). Unit System's Stories 001/002/006 must be implemented first (Movement reads
`UnitTypeDef`/`UnitState`/`UnitConfig`).
