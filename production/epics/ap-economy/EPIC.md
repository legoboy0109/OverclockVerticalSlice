# Epic: AP Economy

> **Layer**: Foundation
> **GDD**: design/gdd/ap-economy.md
> **Architecture Module**: AP Economy
> **Status**: Ready
> **Stories**: 3 stories created — see table below

## Overview

AP Economy is the single per-turn action-point pool that pays for everything a player does —
moving, attacking, producing units, building outposts, and researching all draw from one
budget. At the start of a player's turn the pool resets to a frozen `ap_income` snapshot
(`BASE_INCOME` + tiered per-outpost bonus + an optional Economy Tech term, itself capped); any
AP left unspent at end of turn is discarded (no banking). `AP extends RefCounted` is a static
utility class with `can_afford()` as a pure query and `spend()` as the sole atomic mutator,
gated to the active player. Tuning constants live in a dedicated `EconomyConfig` Resource,
never on `GameState` and never as code literals — this is the balance center of the whole game.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0006: AP economy data model & spend contract | `AP` static utility class (mirrors ADR-0002's verb-handler shape); tuning constants in `EconomyConfig` Resource loaded by a thin `Balance` Autoload; `spend()` sole mutator, atomic, gated to active player; `ap_income_breakdown()` decomposes the frozen snapshot; `AP.current_ap()` pass-through | LOW |
| ADR-0003: Deterministic simulation & RNG isolation | AP trajectory is fully deterministic: identical income + identical ordered actions → bit-identical result, no RNG | LOW |
| ADR-0008: Shared start-of-turn sequencing | Income is evaluated once per start-of-turn reset (step 4 of the canonical sequence), after build/research timers advance (step 3) — a just-completed Economy Outpost counts toward income the same turn | LOW |
| ADR-0012: Faction identity modifier framework | Additive faction income-delta fold (`Δ_base`/`Δ_tier1`/`Δ_tier2`) gated by a `BASE_INCOME_FLOOR` guard; no-op under the VS's Neutral default (all deltas 0) | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-apecon-001 | current_ap stored as state, mutated by exactly 2 paths: turn-manager reset + spend(); int field on per-player state | ADR-0006 ✅ |
| TR-apecon-002 | ap_income(player)->int per tiered formula (BASE + tier1*min(n,THRESH) + tier2*max(0,n-THRESH) + econ-tech term), n=max(0,outposts) | ADR-0006 ✅ |
| TR-apecon-003 | Externalize coefficients: BASE_INCOME=10, OUTPOST_BONUS_TIER1=2, TIER2=1, TIER_THRESHOLD=4, ECONOMY_TECH_TIER_THRESHOLD=6, ECONOMY_TECH_INCOME_BONUS=1; no literals in code | ADR-0006 ✅ |
| TR-apecon-004 | Start-of-turn: eval ap_income once, freeze income_this_turn snapshot; current_ap set to it; no mid-turn recompute (step 3 of turn seq) | ADR-0008 ✅ |
| TR-apecon-005 | End of turn: discard unspent AP (current_ap:=0), immutable through opponent turn; hard write, observable | ADR-0006 ✅ |
| TR-apecon-006 | can_afford(player,amount)->bool pure, callable for any player; all spenders call before offering action | ADR-0006 ✅ |
| TR-apecon-007 | spend(player,amount)->bool sole atomic mutator (reject if not active, <0, >current_ap; no-op if 0); sole cross-system write | ADR-0006 ✅ |
| TR-apecon-008 | Invariant 0<=current_ap<=income_this_turn holds structurally | ADR-0006 ✅ |
| TR-apecon-009 | Read query current_ap + frozen income breakdown (base/outpost/tech); HUD + Cmd interface; frozen snapshot not live recompute | ADR-0006 ✅ |
| TR-apecon-010 | Read completed_outpost_count(player) + has_economy_tech(player) as external deps (Base&Prod + Research); pure/deterministic | ADR-0006 ✅ |
| TR-apecon-011 | All AP-consumers integrate via spend()/can_afford() only; no parallel pool (Pillar 1) | ADR-0006 ✅ |
| TR-apecon-012 | Additive Faction income modifier fold-in (Delta base/tier1/tier2) gated by BASE_INCOME_FLOOR; no-op under Neutral | ADR-0012 ✅ |
| TR-apecon-013 | Full determinism: identical income+actions -> bit-identical AP trajectory, no RNG | ADR-0003 ✅ |
| TR-apecon-014 | Test doubles for completed_outpost_count + has_economy_tech (DI over singletons) | ADR-0006 ✅ |

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | AP Income Formula, EconomyConfig & Balance Autoload | Logic | Ready | ADR-0006 |
| 002 | AP Spend Contract — can_afford & spend | Logic | Ready | ADR-0006 |
| 003 | AP reset_turn & discard — Start-of-Turn Freeze / End-of-Turn Discard | Logic | Ready | ADR-0006 |

> **Cross-epic dependency & implementation order:** All 3 stories read `PlayerState`/`GameState` fields,
> so they depend on **Game State Story 001** (data model), which is implementable now. Story 001's
> `income()` calls forward-declared `BaseProduction.completed_outpost_count` / `Research.economy_tech_income_bonus`
> — per the GDD's stub strategy (TR-apecon-014) these use thin stub classes for unit testing now; real
> bodies land with the entity-schema/Research epics. Story 003 (`reset_turn`/`discard`) **unblocks Game
> State Story 003** (turn sequencing calls them). Resolved order: GS-001 → AP-001 → AP-002 → AP-003 → GS-003 → GS-004.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/ap-economy.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/story-readiness production/epics/ap-economy/story-001-ap-income-econconfig-balance.md` to begin implementation (after GS Story 001 lands — see the cross-epic order above).
