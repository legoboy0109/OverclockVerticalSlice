# Epic: Unit System

> **Layer**: Core
> **GDD**: design/gdd/unit-system.md
> **Architecture Module**: Unit System (Core Layer)
> **Status**: Ready
> **Stories**: 10 stories created (see table below)

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

## Stories

| # | Story | Type | Status | ADR | TRs | VS-critical |
|---|-------|------|--------|-----|-----|-------------|
| 001 | UnitTypeDef template resource + registry | Config/Data | Complete | ADR-0007 | 001, 014 | ✅ (1st) |
| 002 | UnitState runtime schema + stub migration | Logic | Ready | ADR-0007 | 002, 003, 014, 015 | ✅ (2nd) |
| 003 | Pure ops — can_attack, reset_turn_flags, duplicate, apply_hp_delta | Logic | Ready | ADR-0007 | 004, 005, 015 | ✅ (3rd) |
| 004 | effective_attack — live research-tech fold | Logic | Ready | ADR-0007 | 006 | ✅ |
| 005 | effective_defense + two-flag independence | Logic | Ready | ADR-0007 | 006, 007 | ✅ |
| 006 | Movement & AP cost fields (UnitConfig) | Logic | Ready | ADR-0009 | 008, 009 | ✅ |
| 007 | Faction read-sites — effective_produce/move_cost | Logic | Ready | ADR-0012 | 011 | defer |
| 008 | Lifecycle states + edge-case guards | Logic | Ready | ADR-0007 | 012 | ✅ |
| 009 | duplicate()/serialization completeness audit | Logic | Ready | ADR-0001 | 015 | defer |
| 010 | HUD/Command read-surface | UI | Ready | ADR-0016 | 013 | defer |

**All 15 TR-unit-* requirements covered** (no gaps). VS-critical build order: 001 → 002 → 003 → 006 → 004 → 005 → 008.

## Next Step

Run `/story-readiness production/epics/unit-system/story-001-unittypedef-template-registry.md`
to validate the first story, then `/dev-story` to implement. Work in dependency order
(each story's `Depends on:` field gates it). Story 002 closes the Sprint-1 `UnitState`/`Unit`
stub seam — the stubs get deleted, so run it before any Movement/Combat work.
