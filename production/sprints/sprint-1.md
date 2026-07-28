# Sprint 1 — 2026-07-27 to 2026-08-07

## Sprint Goal
Implement the Foundation spine (GameState core + AP Economy) in the resolved cross-epic order, unblocking the Turn FSM and win-check stories that depend on both.

## Capacity
- Total days: 10
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days

> No `production/milestones/` file exists yet. This sprint is scoped against the Foundation-epics roadmap (Grid & Terrain — complete; Game State & Turn Manager + AP Economy — storied and ready) as the de facto milestone, per user confirmation on 2026-07-25.

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| GS-001 | GameState Core — Data Model, Read API & clone() | godot-gdscript-specialist | 0.5 (3-4h) | Grid Story 001 (DONE) | Headless-safe, clone-isolation, clone-determinism, side-effect-free read API, stable entity order, serializable-only fields |
| AP-001 | AP Income Formula, EconomyConfig & Balance Autoload | godot-gdscript-specialist | 0.5 (3-4h) | GS-001; stub BaseProduction/Research | Tiered outpost income curve, Economy Tech term + cap, negative-n clamp, breakdown == total, faction-fold no-op at VS defaults |
| AP-002 | AP Spend Contract — can_afford & spend | godot-gdscript-specialist | 0.5 (2-3h) | AP-001, GS-001 | spend/can_afford correctness incl. 0/negative/exact-zero cases, per-player pool isolation, active-player lock (Rule 7), invariant 0≤ap≤income |
| AP-003 | AP reset_turn & discard | godot-gdscript-specialist | 0.25 (2h) | AP-001, GS-001 | Frozen income snapshot semantics (immune to same-turn ± outposts), discard zeroes current_ap, no banking on reset |
| GS-002 | Action Command Model, apply_action Pipeline & Event Signal | godot-gdscript-specialist | 0.5 (4h) | GS-001 | Validate-before-mutate atomicity, determinism, idempotency-by-revalidation, single synchronous action_applied emission, Dictionary-verb dispatch, faction-lock rejection |
| GS-003 | Turn FSM — start_match, start_turn 4-step sequence, EndTurnAction, round increment | godot-gdscript-specialist | 0.5 (3-4h) | GS-001, GS-002, AP-003 (soft: AP.reset_turn/discard) | start_match sets round 1 + starting AP, end_turn discards+switches+resets opponent, round increments only after both players' turns, step 1→2→3→4 ordering, no softlock |
| GS-004 | Win-Check, GameOver & MAX_ROUNDS/Tiebreak | godot-gdscript-specialist | 0.5 (3h) | GS-002, GS-003; stub entity HP (ADR-0007) | HQ-destruction → synchronous GameOver + GAME_OVER rejection, same-step immediacy, non-active-player-wins tiebreak rule, opt-in MAX_ROUNDS/TIEBREAK_METRIC |

### Should Have
*(none — no additional stories are storied/ready this cycle)*

### Nice to Have
*(none)*

## Carryover from Previous Sprint
*(none — this is Sprint 1; the Grid & Terrain epic was completed and committed prior to this sprint cycle, not carried in)*

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Forward-declared `BaseProduction`/`Research`/entity-HP contracts don't exist yet (AP-001/003, GS-004) | High | Medium | Use thin stub classes per the GDD's stub strategy; tests gate on stubs, not the real systems |
| `duplicate_deep()` clone semantics (ADR-0001, Godot 4.5+) — flagged MEDIUM engine risk | Medium | Medium | Clone-isolation + clone-determinism are explicit ACs on GS-001; verify against `docs/engine-reference/godot/VERSION.md` before implementing |
| No formal milestone file exists to cross-check scope/deadline against | Low | Low | Proceeding on the Foundation-epics roadmap per user confirmation; revisit once a milestone doc exists |
| No risk register exists yet (`production/risk-register/`) | Low | Low | This sprint plan's Risks table is the only risk tracking in place for now |

## Dependencies on External Factors
- None outside the project — implementation order is fully internal to the Foundation epics.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-1.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged

> **Review mode**: `lean` — PR-SPRINT producer feasibility gate skipped for this sprint plan (not a phase gate).

> **QA Plan**: `production/qa/qa-plan-sprint-1-2026-07-26.md`

> **Scope check:** If this sprint includes stories added beyond the original epic scope, run `/scope-check [epic]` to detect scope creep before implementation begins.
