# Epic: Base & Production

> **Layer**: Core
> **GDD**: design/gdd/base-production.md
> **Architecture Module**: Base & Production (Core Layer)
> **Status**: Ready
> **Stories**: 10 stories (see `## Stories` below) — all Ready, none implemented

## Overview

Base & Production owns structures and unit production: structure templates and
instances, build/production queues, and the (disabled) `MAX_OUTPOST_COUNT` cap.
It exposes `build`, `produce`, `cancel_build`, `legal_build_tiles`,
`legal_deploy_tiles`, and `completed_outpost_count` — the last of which the AP
economy's income formula already calls (Sprint 1 stubbed it under
`tests/helpers/stubs/base_production_stub.gd`). This epic delivers the real
`BaseProduction` static utility that replaces that stub, plus the build/research
timer advance (`advance_build_timers`) that GS-003's start-of-turn step 3 calls.
All mutations commit via `apply_action`; structures place into Grid occupancy at
build time (no intangible-under-construction carve-out).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0017: Base & Production mechanics | `BaseProduction` static class; 2-value `BuildStatus`; `legal_build_tiles`/`legal_deploy_tiles` pure live queries; effective production cap two-sided invariant | LOW |
| ADR-0007: Entity/stat schema | Structure templates + instances as `Resource`s | MEDIUM (shared) |
| ADR-0010: Combat | Structure-as-attacker + structure destruction | LOW |
| ADR-0008: Start-of-turn | `advance_build_timers` in step 3 | LOW |
| ADR-0002 / ADR-0006 / ADR-0003 | apply_action commit; AP spend; determinism | LOW |
| ADR-0016: Game HUD | Production read-surface | LOW |

## GDD Requirements

All 17 requirements are ADR-traced (0 untraced). Full requirement text in
`docs/architecture/tr-registry.yaml`.

| Governing ADR | TR-IDs | Coverage |
|---------------|--------|----------|
| ADR-0017 (base/prod) | TR-baseprod-002, -003, -005, -008 | ✅ |
| ADR-0007 (schema) | TR-baseprod-001, -013, -014, -016 | ✅ |
| ADR-0010 (combat) | TR-baseprod-010, -011, -012 | ✅ |
| ADR-0008 (start-of-turn) | TR-baseprod-006, -009 | ✅ |
| ADR-0002 (apply_action) | TR-baseprod-004 | ✅ |
| ADR-0006 (AP) | TR-baseprod-007 | ✅ |
| ADR-0003 (determinism) | TR-baseprod-015 | ✅ |
| ADR-0016 (HUD) | TR-baseprod-017 | ✅ |

**Untraced Requirements**: None.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [Structure Schema, Templates & Config](story-001-structure-schema-templates-config.md) | Logic | ✅ Complete | ADR-0017 (D1/D6), ADR-0007 |
| 002 | [BaseProduction Lands — Build + Timers + Outpost Count + Reset](story-002-build-verb-legal-build-tiles-occupancy.md) | Logic | ✅ Complete | ADR-0017 (D1/D2/D3), ADR-0008, ADR-0002/0005/0006/0012 |
| ~~003~~ | ~~Start-of-Turn Timers, Outpost Count & Flag Reset~~ — **merged into 002** ([superseded](story-003-start-of-turn-timers-outpost-count-flag-reset.md)) | Logic | Superseded | — |
| 004 | [Produce Verb & `legal_deploy_tiles`](story-004-produce-legal-deploy-tiles.md) | Logic | ✅ Complete | ADR-0017 (D4), ADR-0006/0007/0012 |
| 005 | [Cancel Build & Fixed-Point Refund](story-005-cancel-build-refund.md) | Logic | Ready | ADR-0017 (D5/D6) |
| 006 | [Defensive Structure Attack](story-006-defensive-structure-attack.md) | Logic | Ready | ADR-0010, ADR-0017 |
| 007 | [Structure Destruction & HQ Win-Hook](story-007-structure-destruction-hq-win-hook.md) | Logic | Ready | ADR-0010 |
| 008 | [Determinism & Clone Isolation](story-008-determinism-clone-isolation.md) | Logic | Ready | ADR-0003 |
| 009 | [Production HUD Read-Surface](story-009-production-hud-read-surface.md) | UI | Ready | ADR-0016 |
| 010 | [Integration — apply_action End-to-End](story-010-integration-apply-action-end-to-end.md) | Integration | Ready | ADR-0002, ADR-0017 |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/base-production.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- The real `BaseProduction` class replaces the Sprint 1 stub (`completed_outpost_count` + `advance_build_timers`), and AP-income / start-of-turn integration is regression-tested against the real implementation

## Next Step

The 10-story breakdown is authored (all Ready). Story 001 (schema/templates/config) is
the foundation and depends on nothing; Story 010 (integration) depends on 001–007.
Run `/story-readiness [story-file]` before starting a story, then `/dev-story` to implement.
Not on the minimal VS-critical path — schedule after the Unit/Movement/Combat slice.
