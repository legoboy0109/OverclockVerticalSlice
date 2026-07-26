# Epic: Unit System

> **Layer**: Core
> **GDD**: design/gdd/unit-system.md
> **Architecture Module**: Unit System (Core Layer)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories unit-system`

## Overview

The Unit System owns unit data and per-unit runtime state: `UnitStats` templates
(`.tres` resources), and each unit's live `hp`, position, and per-turn flags. It
exposes the read/mutate surface every other Core verb builds on — `can_attack`,
`reset_turn_flags`, `duplicate`, `apply_hp_delta`, `effective_attack`/`effective_defense`
(the faction-fold read sites), and the HUD read-surface. It is the data-schema
foundation of the Core layer: Movement reads unit move costs, Combat reads unit
stats/hp, Base & Production instantiates units, and Research flips the tech flags
units read. This epic delivers the `UnitState`/`StructureState` concrete
`EntityState` subclasses that Sprint 1 stubbed under `tests/helpers/stubs/`
(GS-003 seam) and ADR-0007 defines.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0007: Data-driven entity/stat schema | `UnitStats`/structure/tech templates as typed `Resource`s; static typing; test-injectable; `duplicate_deep()` for clone | **MEDIUM** (`duplicate_deep()` ⚠️ Godot 4.5) |
| ADR-0001: State model / ownership | Per-unit runtime state lives on `EntityState`, cloned with `GameState` | LOW |
| ADR-0010: Combat resolution | `can_attack`/hp-delta contracts consumed by Combat | LOW |
| ADR-0009: Reachable search | Unit move-cost fields consumed by Movement | LOW |
| ADR-0006: AP economy | Unit-production spend | LOW |
| ADR-0012: Faction identity | `effective_attack/defense` fold read-sites (Feature) | LOW |
| ADR-0016: Game HUD | Unit read-surface for HUD | LOW |

## GDD Requirements

All 15 requirements are ADR-traced (0 untraced). Full requirement text in
`docs/architecture/tr-registry.yaml`.

| Governing ADR | TR-IDs | Coverage |
|---------------|--------|----------|
| ADR-0007 (schema) | TR-unit-001, -002, -004, -006, -007, -012, -014 | ✅ |
| ADR-0001 (state) | TR-unit-003, -015 | ✅ |
| ADR-0010 (combat) | TR-unit-005, -010 | ✅ |
| ADR-0009 (movement) | TR-unit-008 | ✅ |
| ADR-0006 (AP) | TR-unit-009 | ✅ |
| ADR-0012 (faction) | TR-unit-011 | ✅ |
| ADR-0016 (HUD) | TR-unit-013 | ✅ |

**Untraced Requirements**: None.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/unit-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- The real `UnitState`/`StructureState` classes replace the GS-003 test stubs under `tests/helpers/stubs/` (delete stubs on landing — class_name collision)

## Next Step

Run `/create-stories unit-system` to break this epic into implementable stories.
This is the VS-critical foundation — build it before Movement and Combat.
