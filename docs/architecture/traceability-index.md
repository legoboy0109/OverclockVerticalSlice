# Architecture Traceability Index — OVERCLOCK

- **Last Updated:** 2026-07-25 (all 18 ADRs Accepted — bottom-up batch, all 4 pre-Accept spikes PASS)
- **Engine:** Redot 26.2 (Godot 4.6-compatible fork)
- **Source:** `/architecture-review` (full) · stable IDs in `docs/architecture/tr-registry.yaml` (v3)

## Coverage Summary

- **Total requirements:** 200
- **Covered** (governing ADR written + specifies the requirement): **200 (100%)**
- **Partial** (governing ADR planned, not yet written): **0**
- **Gaps** (no ADR at all): **0**

> "Covered" means an ADR governing the requirement exists as a file and its own
> "Requirements Addressed" section specifies it. All 18 ADRs are now `Accepted` (2026-07-25,
> bottom-up dependency-order batch) — every requirement below is *implementation-ready* (no ADR
> remains `Proposed`, so no story is auto-blocked per `docs/CLAUDE.md`). The three cross-ADR
> conflicts (C1/C2/C3) found in the 2026-07-24 review are all verified fixed (see the
> resolved-conflicts table below and `architecture-review-2026-07-25.md`). Counts below use each
> TR's **primary governing ADR** (the `adr:` field in `tr-registry.yaml`) and total exactly 200.

## Matrix by ADR (18 written, 200 TRs, 200/200 mapped)

| ADR | Title | Layer | Written? | Status | # TRs | Coverage |
|-----|-------|-------|----------|--------|-------|----------|
| ADR-0001 | State model ownership & lifecycle | Foundation | ✅ | Accepted | 14 | ✅ Covered |
| ADR-0002 | Action / apply_action command model | Foundation | ✅ | Accepted | 7 | ✅ Covered |
| ADR-0003 | Deterministic simulation & RNG isolation | Foundation | ✅ | Accepted | 10 | ✅ Covered |
| ADR-0004 | Event / signal architecture | Foundation | ✅ | Accepted | 4 | ✅ Covered |
| ADR-0005 | Grid representation & map format | Foundation | ✅ | Accepted | 11 | ✅ Covered |
| ADR-0006 | AP economy data model & spend contract | Foundation | ✅ | Accepted | 15 | ✅ Covered |
| ADR-0007 | Unit & Structure entity/stat schema | Foundation | ✅ | Accepted | 17 | ✅ Covered |
| ADR-0008 | Shared start-of-turn sequencing | Foundation | ✅ | Accepted | 6 | ✅ Covered |
| ADR-0009 | Reachable-search / pathfinding | Core | ✅ | Accepted | 10 | ✅ Covered |
| ADR-0010 | Combat resolution & destruction/win-check | Core | ✅ | Accepted | 17 | ✅ Covered |
| ADR-0011 | AI opponent decision loop | Feature | ✅ | Accepted | 18 | ✅ Covered |
| ADR-0012 | Faction identity modifier framework | Feature | ✅ | Accepted | 17 | ✅ Covered |
| ADR-0013 | Isometric board rendering, picking & overlays | Presentation | ✅ | Accepted | 7 | ✅ Covered |
| ADR-0014 | Input & focus architecture | Presentation | ✅ | Accepted | 7 | ✅ Covered |
| ADR-0015 | Command & action interface FSM | Presentation | ✅ | Accepted | 14 | ✅ Covered |
| ADR-0016 | Game HUD (facade, AP-counter FSM, audio) | Presentation | ✅ | Accepted | 19 | ✅ Covered |
| ADR-0017 | Base & Production mechanics | Core | ✅ | Accepted | 4 | ✅ Covered |
| ADR-0018 | Research/Tech mechanics | Core | ✅ | Accepted | 3 | ✅ Covered |

*All 18 ADRs Accepted 2026-07-25 (bottom-up dependency-order batch). ADR-0013/0014's pre-Accept
engine spikes (iso picking, dual-focus) both cleared PASS the same day (user, windowed Redot
session), alongside QQ-05 (→ADR-0009) and QQ-06 (→ADR-0011) — all four gating spikes are now
recorded in their respective ADRs' Validation Criteria / Status sections.*

## Cross-ADR Conflicts — ✅ all resolved 2026-07-24 (same session)

| ID | Severity | ADRs | Summary | Resolution |
|----|----------|------|---------|-----|
| C3 | 🔴 HIGH | 0006 ↔ 0007 | `economy_tech_income_bonus` tier cap applied twice (income squared in tier factor) | ✅ ADR-0006 `income()` now sums `ap_income_breakdown()`, which adds ADR-0007's already-capped term verbatim (no re-cap). ADR-0007 unchanged (behaviorally correct); ownership annotated. |
| C1 | MEDIUM | 0006 ↔ 0011/0015/0016 | `AP.current_ap()` called but never declared on `AP` (it's `GameState.current_ap`) | ✅ Added `AP.current_ap(state, player)` pass-through to ADR-0006; the three consumers now resolve as written. |
| C2 | LOW | 0006 ↔ 0016 | `AP.ap_income_breakdown()` consumer-declared only (already in architecture.md) | ✅ `AP.ap_income_breakdown(state,player)->{base,outpost,econ_tech}` now declared & implemented in ADR-0006; `income()` is its sum. |

*These conflicts were found and fixed in the 2026-07-24 session; the 2026-07-25 full review
re-verified all three fixes hold in ADR-0006. The inline `⚠️Cn` markers have been cleared from the
ADR matrix above now that the fixes are confirmed; this table is retained for audit trail.*

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

## Known Gaps / Partial

**None.** 200/200 TRs are Covered by a written governing ADR. The 18-ADR plan is complete for the
Vertical-Slice scope — no further ADRs are required (the deferred Persistence & Campaign system and
Full-Vision Vehicle/Mech tier are out of VS scope and will get their own ADRs when designed).

**Remaining path to gate-readiness** (tracked in `architecture-review-2026-07-25.md`, not coverage
gaps):

1. ✅ DONE — all four pre-Accept spikes (QQ-05 →ADR-0009, QQ-06 →ADR-0011, ADR-0013 iso-picking,
   ADR-0014 dual-focus) cleared PASS 2026-07-25.
2. ✅ DONE — ADR-0018 D1 `@export` annotation nit fixed 2026-07-25.
3. ✅ DONE — all 18 ADRs Accepted bottom-up in dependency order (0001→0018), 2026-07-25.

## Superseded Requirements

None — registry `version: 3`. No TR-ID has been revised, deprecated, or superseded. The v3 bump
re-pointed 7 `adr:` fields (baseprod-002/003/005/008 → ADR-0017; research-003/004/005 → ADR-0018);
no IDs were renumbered.

**2026-08-26 — CR-4 structural/situational clarification: still none, and that is the finding.**
`/propagate-design-change` ran on `command-action-interface.md` CR-4 after S8-10 changed which
disabled verbs render (`change-impact-2026-08-26-action-menu-cr4.md`). **0 of 18 ADRs and 0 of 24
`TR-cmdui-*` were affected** — the structural filter lives in the *view*
(`ActionMenu._is_inapplicable`), while ADR-0015's `menu_model` still returns `{verb, enabled,
reason}` for every verb, so the architectural contract never moved. ⚠ The reason nothing traced is
that **the disabled-vs-hidden rule was never encoded as a TR** — it existed only as GDD prose, which
is how a dead "Produce — not a producer" row shipped on every unit and survived a full art sprint
and two spec reviews. Deliberately still not given a TR (it is a presentation rule with no
architectural consequence), but recorded: *the rules most likely to rot quietly are the ones no
downstream artifact depends on.*
