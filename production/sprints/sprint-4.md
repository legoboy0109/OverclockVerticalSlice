# Sprint 4 — 2026-07-29 to 2026-08-12 (Vertical Slice Validation)

## Sprint Goal
Validate the Vertical Slice — produce representative art, run the iso-legibility +
swing-back playtests, write the PROCEED / PIVOT / KILL REPORT, and clear the
Pre-Production → Production gate that Sprint 3 left at **CONCERNS**
(`production/gate-checks/gate-pre-production-production-2026-07-28.md`).

## Capacity
- Total days: 10 (2-week sprint)
- Buffer (20%): 2 days reserved for unplanned work
- Available: ~8 days

> **★ = human-gated** (art creation / playtest sessions / windowed sign-off) — cannot
> be fully agent-completed. Per retrospective action #5 (`retro-sprint-3-2026-07-28.md`),
> the sprint front-loads this track, which was the recurring 0%-completion half in
> Sprint 3.

## Tasks

### Must Have (Critical Path — clear the gate)
| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S4-01 | De-risk spikes: Boom-cyan vs Dark-Stage hue side-by-side + glow-shader 2D/uniform *(carryover s3-08)* | art-director / technical-artist | 0.5 | — | Hue test + shader verdict recorded in `design/art/art-bible.md`; unblocks art |
| S4-02 | ★ Representative Neon Retro-Future art — 5 entities + 2 terrain tiles *(carryover s3-06)* | art-director | 3 | S4-01 | Assets meet art-bible specs; imported under `assets/` |
| S4-03 | Entity sprite renderer + live `GameState.entities()`→board feed (replace placeholder diamonds; closes scope §8 build-seam c) | godot-gdscript-specialist | 1.5 | S4-02 | Real sprites y-sort on OccupantLayer; boot + integration tests green |
| S4-04 | ★ Iso-legibility playtest (Pillar-3 hard gate) *(carryover s3-09)* | ux-designer / qa-tester | 0.5 | S4-03 | ≥1 documented naive/silent-observer session; board readable at the shipping camera; silhouettes distinguishable in grayscale; ownership clear by hue → `production/playtests/` |
| S4-05 | ★ Swing-back playtest — tempo/comeback (testable on the current build now) *(carryover s3-10)* | game-designer / qa-tester | 1 | — | ≥1 documented session (DoD floor); ≥3 close + ≥3 decided games preferred; closeout-drag observation captured; **no decided game reverses** |
| S4-06 | VS REPORT + PROCEED/PIVOT/KILL verdict + re-run `/gate-check pre-production` *(carryover s3-11)* | creative-director + producer | 0.5 | S4-04, S4-05 | `REPORT.md` with verdict + velocity log; gate re-run outcome recorded |

### Should Have
| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S4-07 | ★ Advisory Visual/Feel sign-offs (BR-002/003/005, CAI-006, HUD-004/005/007) — windowed screenshots | qa-lead / art-director | 1 | S4-02 | Evidence docs in `production/qa/evidence/` signed off |
| S4-08 | Occupant pick-region authoring + mouse click-select (closes scope §8 build-seam b) | godot-gdscript-specialist | 1 | S4-03 | Click-to-select resolves the occupant via `CommandInterface.route_click`; integration test |

### Nice to Have
| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S4-09 | Small committed-code follow-ups: ap_counter `→`→ASCII; enforce `pass_threshold` in `AI.choose_action` | godot-gdscript-specialist | 0.5 | — | No tofu in the AP echo; sub-threshold candidates rejected (choose_action returns null) + test |
| S4-10 | HUD chrome `/ux-design` pass — finalize the provisional slice HUD + fold the status/legend overlay into a proper HUD control | ux-designer | 1 | — | UX spec authored + `/ux-review` APPROVED |

## Carryover from Sprint 3
| Task | Reason | New Estimate |
|------|--------|--------------|
| s3-08 de-risk spikes → S4-01 | Never started in S3; blocks art | 0.5 |
| s3-06 representative art → S4-02 | Blocked on spikes | 3 |
| s3-09/10/11 playtests + REPORT → S4-04/05/06 | Sanctioned validation-half rollover (scope §9) | 2 |
| s3-05 build-seams → S4-03 (live entities feed) / S4-08 (occupant pick-region) | Two of the three §8 seams still open (selection_changed landed w/ HUD facade) | folded |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Art (S4-02, human-gated, 3d) slips → blocks legibility playtest + gate | High | High | Run S4-01 spikes first (de-risk); S4-05 swing-back is art-independent — run in parallel |
| Playtests need a human + a naive observer | Medium | Medium | DoD floor = ≥1 documented session; self-test + team rotation acceptable (think-aloud preferred) |
| Swing-back: a *decided* game reverses | Low | High | The one hard "must not happen" observation → triggers economy re-tuning (PIVOT, not KILL) |
| Verdict lands PIVOT (muted swing-back / unreadable board) | Medium | Medium | Sanctioned outcome, not a failure → spawns a focused tuning/art follow-up, then re-gate |

## Dependencies on External Factors
- A human at a windowed Redot editor for the playtests (S4-04/05) and advisory
  visual sign-offs (S4-07). The developer confirmed windowed-build access (pull
  `main` on a display PC).
- Art asset creation (S4-02) — artist time or AI generation + integration per the
  art bible.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed and passing acceptance criteria
- [ ] ≥1 iso-legibility **and** swing-back playtest documented in `production/playtests/`
- [ ] `REPORT.md` with a PROCEED/PIVOT/KILL verdict; `/gate-check pre-production` re-run and recorded
- [ ] Real art rendered (placeholder diamonds removed); `/smoke-check` still PASS, no regressions
- [ ] QA plan exists (`production/qa/qa-plan-sprint-4.md`)
- [ ] Code reviewed and merged; no S1/S2 bugs in delivered features
- [ ] Design/architecture docs updated for any deviations (esp. a PIVOT outcome)

## Origin
Sprint 4 is the **validation opener** the Sprint 3 close-out set up: Sprint 3
delivered a complete, playable, regression-hardened Vertical Slice (build 100%),
but the Pre-Production → Production gate is CONCERNS pending the playtests + verdict.
This sprint completes that validation half to reach the gate's true PROCEED decision.
