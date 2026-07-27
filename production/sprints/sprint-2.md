# Sprint 2 — 2026-08-10 to 2026-08-21 (Vertical Slice Enablement)

## Sprint Goal
Produce everything required to build and playtest a Vertical Slice next sprint —
break the Core layer into a real backlog, retire the two blocking rulings/spikes,
scope the slice, and land the UX/art artifacts the slice depends on. This is the
sprint that clears the four CONCERNS from the 2026-07-26 Pre-Prod → Production gate
(`production/gate-checks/2026-07-26-pre-production-to-production.md`).

## Capacity
- Total days: 10
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days

> This is a Pre-Production **planning + de-risking** sprint, not a code-implementation
> sprint. Tasks produce design/planning artifacts, spikes, and a backlog — so the
> usual "Logic stories have passing tests" DoD applies only to the QQ spikes (which
> ship measurement code), not the planning tasks.

## Tasks

### Must Have (Critical Path — clears the gate blockers)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S2-01 | Core-layer epic + story breakdown for the VS-critical path (movement → command-action-interface → combat → HUD → minimal AI) via `/create-epics layer:core` then `/create-stories` | producer + technical-director | 2.5 | Accepted ADRs (done), control manifest (done) | Epics exist in `production/epics/` for the 5 VS-critical Core systems; each has stories with estimates, embedded TR-IDs + governing ADR, and dependency order |
| S2-02 | Resolve the per-player-index guard ruling (trusted-API-crash vs. bounds-guards) — ADR addendum or control-manifest guardrail | technical-director | 0.5 | tech-debt entry | One documented ruling applied across the Foundation read surface; control manifest / ADR updated; tech-debt entry closed |
| S2-03 | Complete QQ-05 (reachable/pathfinding perf) + run QQ-06 (AI lookahead perf) spikes | performance-analyst | 1.5 | ADR-0009, ADR-0011 | Both spikes produce measured numbers vs. budget + a PROCEED/ADJUST verdict; movement (ADR-0009) and AI (ADR-0011) epics gated on their result |
| S2-04 | Vertical Slice scope definition (one playable turn: move → spend AP → attack → resolve → win-check → minimal AI reply, on a rendered board) via `/vertical-slice` scoping | creative-director + producer | 1 | S2-01 | A written VS scope doc naming exactly which systems/stories are in-slice, the two mandated playtests (iso-legibility, swing-back), and PROCEED/PIVOT/KILL criteria |

### Should Have (parallel — needed before the VS build / Production)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S2-05 | UX specs for the VS screens: core HUD (VS dependency), main menu, pause | ux-designer | 1.5 | game-hud GDD | `design/ux/hud.md` + main-menu + pause specs exist and pass `/ux-review`; accessibility tier addressed |
| S2-06 | Record the AD-ART-BIBLE sign-off verdict in the art bible | art-director | 0.25 | art-bible (done) | Sign-off verdict + date recorded in `design/art/art-bible.md` |
| S2-07 | Entity inventory for VS-scope entities (HQ, VS infantry roster, outpost) via `/asset-spec` | art-director | 0.75 | art bible, GDDs | `design/assets/entity-inventory.md` lists every VS entity with a spec stub |

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S2-08 | Difficulty-curve + player-journey design docs | game-designer + ux-designer | 1 | — | `design/difficulty-curve.md` + `design/player-journey.md` drafted |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| None | Sprint 1 closed 7/7 complete, QA APPROVED | — |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Core breakdown (S2-01) balloons past estimate — 9 systems is large | Medium | High | Scope S2-01 to the **5 VS-critical systems only**; defer base-production/research/faction epics to the first real Production sprint |
| QQ-06 AI spike reveals lookahead is too slow (ADR-0011 stall ceiling breached) | Low-Med | High | Spike *before* committing the AI epic (that's the point); if it fails, ADR-0011 revises its search strategy before any story is written |
| Planning sprint has no code/test evidence → weaker "done" signal | Low | Low | QQ spikes ship measured artifacts; planning tasks gated by artifact existence + review, not tests |

## Dependencies on External Factors
- None. All inputs (GDDs, ADRs, manifest, Foundation code) are in-repo and complete.

> **QA Plan — deferred to Sprint 3 (decided 2026-07-26):** Sprint 2 is a planning +
> de-risking sprint; its only testable output is the QQ-05/QQ-06 spike measurement
> code. The real QA plan (`/qa-plan sprint`) is authored for Sprint 3 — the Vertical
> Slice build — which is the first sprint with testable implementation stories. QQ
> spikes should still ship passing measurement tests where applicable (S2-03 AC).

## Definition of Done for this Sprint
- [x] All Must Have tasks completed — S2-01/02/03/04 all done 2026-07-27
- [x] Core VS-critical epics + stories exist and pass `/story-readiness` — S2-01 done 2026-07-27: 4 epics (board-renderer, command-action-interface, game-hud, ai-opponent) + 30 stories
- [x] Per-player-index ruling applied; QQ-05/QQ-06 verdicts recorded — S2-02 ruling applied 2026-07-27; QQ-05 (~2.0ms/call) + QQ-06 (~3.7ms p95) both PASS, ADR-0009/0011 Accepted 2026-07-25
- [x] VS scope doc written with PROCEED/PIVOT/KILL criteria — S2-04 done 2026-07-27: `production/vertical-slice/scope.md` (short-skirmish, Move+Attack+Produce; iso-legibility + swing-back playtests; CD sign-off CONFIRM WITH AMENDMENTS A/B/C applied)
- [ ] QQ spike code has passing measurement tests where applicable
- [x] Design/UX/art artifacts reviewed (`/ux-review`, AD sign-off) — S2-05 UX specs `/ux-review` APPROVED 2026-07-27; S2-06 AD-ART-BIBLE APPROVE recorded 2026-07-27
- [ ] Ready to run `/vertical-slice` (build) in Sprint 3

---

## Origin
Planned 2026-07-26 following the Sprint 1 close-out. Directly addresses the four
unanimous CONCERNS from the Pre-Production → Production gate:
- **Creative** (unplayed pillars) → S2-04 VS scoping (build/playtest is Sprint 3)
- **Technical** (index ruling, perf spikes) → S2-02, S2-03
- **Producer** (no Core backlog, no fun-validation) → S2-01, S2-04
- **Art** (sign-off, entity inventory, HUD spec) → S2-05, S2-06, S2-07
