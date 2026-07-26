# Epic: Movement

> **Layer**: Core
> **GDD**: design/gdd/movement-system.md
> **Architecture Module**: Movement (Core Layer)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories movement`

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
| ADR-0009: Reachable search / pathfinding | Hand-rolled BFS over flat visited/cost arrays; `reachable()` returns tile + min_cost + is_surcharged; no `AStarGrid2D` | LOW *(QQ-05 perf spike pending — Sprint 2 S2-03)* |
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

**Untraced Requirements**: None.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/movement-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- The QQ-05 reachable/pathfinding perf spike (Sprint 2 S2-03) has a PROCEED verdict before movement stories are estimated/committed

## Next Step

Run `/create-stories movement` to break this epic into implementable stories.
**Gate story creation on the QQ-05 perf spike result** (S2-03) — its outcome may
change the allocation/enumeration strategy. VS-critical: build after Unit System.
