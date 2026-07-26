# Epic: Combat Resolution

> **Layer**: Core
> **GDD**: design/gdd/combat-resolution.md
> **Architecture Module**: Combat Resolution (Core Layer)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories combat-resolution`

## Overview

Combat Resolution owns the attack verb: the damage formula, targeting, counter
logic, and the destruction/win-check hook. It exposes `legal_targets(unit[, from_tile])`
(with the hypothetical-tile overload for move-then-attack preview), `preview_damage`,
`attack(attacker, target) → Result`, and the three blocked-shot reasons. It is the
producer of the `StructureDestroyedEvent{is_hq}` that GS-004's win-check consumes
(the GS-004 seam — this epic delivers the real Combat `destroy_entity()` hook and
reconciles the forward-declared event). All resolution is integer-only and
deterministic; every attack commits atomically through `apply_action`, and an
HQ reaching 0 hp triggers the synchronous GameOver already wired in GS-004.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0010: Combat resolution / destruction / win-check | Damage/targeting/counter formula; shared `destroy_entity()`; `StructureDestroyedEvent{is_hq}` → win-check scan | LOW |
| ADR-0007: Entity/stat schema | Reads unit/structure combat stats (`defense`, `min_range`, `can_counterattack`) | MEDIUM (shared) |
| ADR-0003: Deterministic simulation | Integer damage math; stable targeting order | LOW |

## GDD Requirements

All 14 requirements are ADR-traced (0 untraced). Full requirement text in
`docs/architecture/tr-registry.yaml`.

| Governing ADR | TR-IDs | Coverage |
|---------------|--------|----------|
| ADR-0010 (combat) | TR-combat-001, -002, -003, -004, -005, -006, -007, -008, -009, -012, -014 | ✅ |
| ADR-0007 (stats) | TR-combat-010, -011 | ✅ |
| ADR-0003 (determinism) | TR-combat-013 | ✅ |

**Untraced Requirements**: None.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/combat-resolution.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- The real `StructureDestroyedEvent` producer (`destroy_entity()`) replaces GS-004's forward-declared event; the win-check integration is regression-tested end-to-end (attack → HP → HQ destruction → GameOver)

## Next Step

Run `/create-stories combat-resolution` to break this epic into implementable stories.
VS-critical: build after Unit System + Movement (needs unit stats + move-then-attack).
