# Epic: Research / Tech

> **Layer**: Core
> **GDD**: design/gdd/research-tech.md
> **Architecture Module**: Research / Tech (Core Layer)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories research-tech`

## Overview

Research / Tech owns the tech progression verb: per-player permanent tech-unlock
flags (`has_attack_tech`/`has_defense_tech`/`has_economy_tech`), per-Lab research
state, and the tech table. It exposes `legal_research_targets`, `start_research`,
`cancel_research`, and the `has_*_tech` flags that Unit/Combat/AP read. It is a
Core spend-verb (not opponent policy), committing through `apply_action`. This
epic delivers the real `Research` static utility that replaces Sprint 1's stub
(`economy_tech_income_bonus` — the AP-income tech term — plus `advance_research_timers`
that GS-003's start-of-turn step 3 calls). Tech status is derived, never stored in
a per-(player,tech) table; unlocks are permanent (survive Lab destruction).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0018: Research & Tech mechanics | `Research` static class; permanent `@export` bool flags; per-Lab state on `StructureState`; cross-Lab same-tech mutual exclusion; derived status | LOW |
| ADR-0007: Entity/stat schema | Tech table + per-Lab state as `Resource`s / on `StructureState` | MEDIUM (shared) |
| ADR-0008: Start-of-turn | `advance_research_timers` in step 3 | LOW |
| ADR-0010: Combat | Shared Lab-destruction trigger path | LOW |
| ADR-0002 / ADR-0006 / ADR-0003 / ADR-0001 | apply_action; AP spend; determinism; state | LOW |
| ADR-0016: Game HUD | Research read-surface | LOW |

## GDD Requirements

All 13 requirements are ADR-traced (0 untraced). Full requirement text in
`docs/architecture/tr-registry.yaml`.

| Governing ADR | TR-IDs | Coverage |
|---------------|--------|----------|
| ADR-0018 (research) | TR-research-003, -004, -005 | ✅ |
| ADR-0007 (schema) | TR-research-001, -002, -009 | ✅ |
| ADR-0002 (apply_action) | TR-research-006 | ✅ |
| ADR-0008 (start-of-turn) | TR-research-007 | ✅ |
| ADR-0010 (combat/destruction) | TR-research-008 | ✅ |
| ADR-0006 (AP) | TR-research-010 | ✅ |
| ADR-0003 (determinism) | TR-research-011 | ✅ |
| ADR-0001 (state) | TR-research-012 | ✅ |
| ADR-0016 (HUD) | TR-research-013 | ✅ |

**Untraced Requirements**: None.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/research-tech.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- The real `Research` class replaces the Sprint 1 stub (`economy_tech_income_bonus` + `advance_research_timers`), and AP-income / start-of-turn integration is regression-tested against the real implementation

## Next Step

Run `/create-stories research-tech` to break this epic into implementable stories.
Not on the minimal VS-critical path — schedule after the Unit/Movement/Combat slice.
