# Architecture Traceability Index — OVERCLOCK

- **Last Updated:** 2026-07-24 (re-validation — all 16 ADRs now written; 7 TRs re-pointed to planned ADR-0017/0018)
- **Engine:** Redot 26.2 (Godot 4.6-compatible fork)
- **Source:** `/architecture-review` (full) · stable IDs in `docs/architecture/tr-registry.yaml` (v3)

## Coverage Summary

- **Total requirements:** 200
- **Covered** (governing ADR written + specifies the requirement): **193 (96.5%)**
- **Partial** (governing ADR planned, not yet written — ADR-0017/0018): **7 (3.5%)**
- **Gaps** (no ADR at all): **0**

> "Covered" means an ADR governing the requirement exists as a file and its own
> "Requirements Addressed" section specifies it. All 16 written ADRs are `Proposed`, not
> `Accepted` — so no requirement is yet *implementation-ready* (stories referencing `Proposed`
> ADRs are auto-blocked per `docs/CLAUDE.md`), and three conflicts (C1/C2/C3, see the review
> report) must be reconciled before Accept. Counts below use each TR's **primary governing ADR**
> (the `adr:` field in `tr-registry.yaml`) and total exactly 200.

## Matrix by ADR (16 written + 2 planned, 200 TRs, 200/200 mapped)

| ADR | Title | Layer | Written? | Status | # TRs | Coverage |
|-----|-------|-------|----------|--------|-------|----------|
| ADR-0001 | State model ownership & lifecycle | Foundation | ✅ | Proposed | 14 | ✅ Covered |
| ADR-0002 | Action / apply_action command model | Foundation | ✅ | Proposed | 7 | ✅ Covered |
| ADR-0003 | Deterministic simulation & RNG isolation | Foundation | ✅ | Proposed | 10 | ✅ Covered |
| ADR-0004 | Event / signal architecture | Foundation | ✅ | Proposed | 4 | ✅ Covered |
| ADR-0005 | Grid representation & map format | Foundation | ✅ | Proposed | 11 | ✅ Covered |
| ADR-0006 | AP economy data model & spend contract | Foundation | ✅ | Proposed | 15 | ✅ Covered ⚠️C1/C2/C3 |
| ADR-0007 | Unit & Structure entity/stat schema | Foundation | ✅ | Proposed | 17 | ✅ Covered ⚠️C3 |
| ADR-0008 | Shared start-of-turn sequencing | Foundation | ✅ | Proposed | 6 | ✅ Covered |
| ADR-0009 | Reachable-search / pathfinding | Core | ✅ | Proposed | 10 | ✅ Covered |
| ADR-0010 | Combat resolution & destruction/win-check | Core | ✅ | Proposed | 17 | ✅ Covered |
| ADR-0011 | AI opponent decision loop | Feature | ✅ | Proposed | 18 | ✅ Covered ⚠️C1 |
| ADR-0012 | Faction identity modifier framework | Feature | ✅ | Proposed | 17 | ✅ Covered |
| ADR-0013 ⚠️HIGH | Isometric board rendering, picking & overlays | Presentation | ✅ | Proposed | 7 | ✅ Covered |
| ADR-0014 ⚠️HIGH | Input & focus architecture | Presentation | ✅ | Proposed | 7 | ✅ Covered |
| ADR-0015 | Command & action interface FSM | Presentation | ✅ | Proposed | 14 | ✅ Covered ⚠️C1 |
| ADR-0016 | Game HUD (facade, AP-counter FSM, audio) | Presentation | ✅ | Proposed | 19 | ✅ Covered ⚠️C1/C2 |
| **ADR-0017** | **Base & Production mechanics** | **Core** | ❌ | **planned** | **4** | ⚠️ **Partial** |
| **ADR-0018** | **Research/Tech mechanics** | **Core** | ❌ | **planned** | **3** | ⚠️ **Partial** |

*All 16 ADRs authored (all `Proposed`). The two planned ADRs (0017/0018) govern the 7 Base &
Production / Research mechanic TRs re-pointed off ADR-0010 this run — see the Coverage Gap
section of `architecture-review-2026-07-24.md`. `⚠️Cn` marks ADRs touched by a cross-ADR
conflict.*

## Cross-ADR Conflicts — ✅ all resolved 2026-07-24 (same session)

| ID | Severity | ADRs | Summary | Resolution |
|----|----------|------|---------|-----|
| C3 | 🔴 HIGH | 0006 ↔ 0007 | `economy_tech_income_bonus` tier cap applied twice (income squared in tier factor) | ✅ ADR-0006 `income()` now sums `ap_income_breakdown()`, which adds ADR-0007's already-capped term verbatim (no re-cap). ADR-0007 unchanged (behaviorally correct); ownership annotated. |
| C1 | MEDIUM | 0006 ↔ 0011/0015/0016 | `AP.current_ap()` called but never declared on `AP` (it's `GameState.current_ap`) | ✅ Added `AP.current_ap(state, player)` pass-through to ADR-0006; the three consumers now resolve as written. |
| C2 | LOW | 0006 ↔ 0016 | `AP.ap_income_breakdown()` consumer-declared only (already in architecture.md) | ✅ `AP.ap_income_breakdown(state,player)->{base,outpost,econ_tech}` now declared & implemented in ADR-0006; `income()` is its sum. |

*The ⚠️Cn markers in the ADR matrix above refer to these now-resolved conflicts (kept for audit trail).*

## Full Requirement → ADR Matrix

See `docs/architecture/tr-registry.yaml` for the complete, machine-readable mapping of all 200
`TR-<system>-NNN` IDs → governing ADR → GDD source → requirement text. Summary by system
(primary governing ADR, totals to 200):

| System | GDD | # TRs | Governing ADRs (count) |
|--------|-----|-------|------------------------|
| Grid & Terrain | grid-terrain.md | 15 | ADR-0005 (11), ADR-0001 (2), ADR-0011 (1), ADR-0013 (1) |
| Game State & Turn Manager | game-state-turn-manager.md | 19 | ADR-0001 (9), ADR-0002 (4), ADR-0003 (2), ADR-0008 (2), ADR-0004 (1), ADR-0011 (1) |
| AP Economy | ap-economy.md | 14 | ADR-0006 (11), ADR-0003 (1), ADR-0008 (1), ADR-0012 (1) |
| Unit System | unit-system.md | 15 | ADR-0007 (7), ADR-0001 (2), ADR-0010 (2), ADR-0006 (1), ADR-0009 (1), ADR-0012 (1), ADR-0016 (1) |
| Movement System | movement-system.md | 14 | ADR-0009 (9), ADR-0003 (3), ADR-0002 (1), ADR-0007 (1) |
| Combat Resolution | combat-resolution.md | 14 | ADR-0010 (11), ADR-0007 (2), ADR-0003 (1) |
| Base & Production | base-production.md | 17 | ADR-0007 (4), **ADR-0017 (4)**, ADR-0010 (3), ADR-0008 (2), ADR-0002 (1), ADR-0003 (1), ADR-0006 (1), ADR-0016 (1) |
| Research / Tech | research-tech.md | 13 | ADR-0007 (3), **ADR-0018 (3)**, ADR-0010 (1), ADR-0001 (1), ADR-0002 (1), ADR-0003 (1), ADR-0006 (1), ADR-0008 (1), ADR-0016 (1) |
| Command & Action Interface | command-action-interface.md | 24 | ADR-0015 (14), ADR-0014 (6), ADR-0013 (4) |
| Game HUD | game-hud.md | 23 | ADR-0016 (16), ADR-0004 (3), ADR-0013 (2), ADR-0006 (1), ADR-0014 (1) |
| AI Opponent | ai-opponent.md | 17 | ADR-0011 (16), ADR-0003 (1) |
| Faction Identity | faction-identity.md | 15 | ADR-0012 (15) |

## Known Gaps / Partial (governing ADR planned, not yet written)

Two ADRs remain to fully close Core-layer coverage:

1. **ADR-0017 — Base & Production Mechanics** *(Core)* — build FSM (TR-baseprod-002),
   structure tile/blocker/targetability rules (003), `legal_build_tiles` (005),
   `produce`/`legal_deploy_tiles` (008). Signatures already forward-declared in ADR-0011/0015.
2. **ADR-0018 — Research/Tech Mechanics** *(Core)* — per-player tech-unlock flags
   (TR-research-003), per-Lab research state + mutual exclusion (004),
   `legal_research_targets` (005). Signatures already forward-declared in ADR-0011/0015.

Create each with `/architecture-decision`, then re-run `/architecture-review` to confirm the 7
Partial TRs flip to Covered. Separately, fix conflicts C1/C2/C3 in ADR-0006/0007 (one line each)
while they are still `Proposed`, then Accept all ADRs bottom-up in dependency order starting with
ADR-0001.

## Superseded Requirements

None — registry `version: 3`. No TR-ID has been revised, deprecated, or superseded. The v3 bump
re-pointed 7 `adr:` fields (baseprod-002/003/005/008 → ADR-0017; research-003/004/005 → ADR-0018);
no IDs were renumbered.
