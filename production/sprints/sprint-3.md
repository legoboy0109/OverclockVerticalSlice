# Sprint 3 — 2026-07-28 to 2026-08-08 (Vertical Slice Build)

> **Date note (Sprint 2 retro action #3):** the project is running ~2 weeks ahead of the
> original schedule, so Sprint 3 starts now (2026-07-28), superseding the previously-planned
> 2026-08-10 window. Sprint 4 (contingency) shifts earlier correspondingly.

## Sprint Goal
Build the playable Vertical Slice — a rendered, clickable one-close-skirmish loop
(move / attack / produce → resolve → win-check → minimal AI reply) at representative Neon
Retro-Future quality — and run the first iso-legibility + swing-back playtests toward a
PROCEED / PIVOT / KILL verdict. This is the true Pre-Production → Production gate
(`production/vertical-slice/scope.md`).

## Capacity
- Total days: 10
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days

> ⚠️ **Capacity reality (producer judgment; PR-SPRINT gate skipped — lean mode):** the full VS
> build — 26 in-slice stories + representative art + the two playtests — is ≈ **18+ estimate-days**
> against 8 available. This is a ~2-sprint effort, and the scope doc already sanctioned it:
> **Sprint 4 is the planned contingency** (`scope.md` §9). Sprint 3 targets a *demonstrable
> playable build + first playtest pass*; the full playtest sampling and final verdict are the
> explicit Sprint-4 overflow. The **Day-3 sunk-cost checkpoint** (scope §9) applies: if the full
> loop is not demonstrable by build-day 3, stop and surface the blocker.

## Tasks

### Must Have (Critical Path — a playable, rendered VS build)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S3-01 | **Board Renderer** — 5 in-slice stories (iso transform, y-sort scene, overlay TileMapLayer API, pick-at, glyph anchoring) | godot-specialist → gameplay-programmer | 2.5 | grid-terrain (Complete), ADR-0013 | All 5 BR stories pass ACs; board renders + picks at the shipping isometric camera; grid↔screen round-trip identity test green; `local_to_map` avoided (custom math) |
| S3-02 | **Command & Action Interface** — 8 in-slice stories (FSM core, four-tier recompute, dependency-consumption contracts, cancel gesture, board-cursor substrate, iso-picking/overlay integration, commit-dispatch/input-lock/shared signal, post-commit reselection + game-over convergence) | gameplay-programmer | 3 | S3-01 (picking/overlays); CAI ADRs | 8 CAI stories pass ACs; hover→preview→commit works end-to-end; AP preview snaps; GAME_OVER surfaces |
| S3-03 | **AI Opponent** — 6 in-slice stories (config+invariant, query-facade enumeration, combat+production scoring, economy+positional scoring, tiebreak comparator, turn-driver loop) | ai-programmer | 2 | headless (parallelizable); QQ-06 PASS | 6 AI stories pass ACs; AI takes a full credible turn headlessly; determinism + perf (ports QQ-06) tests green |
| S3-04 | **Game HUD** — 7 in-slice stories (reader facade, config-cross-guard, AP-counter FSM, AP-counter widget, on-board glyph layer, detail-panel + game-over precedence, action-log + income + produce controls) | ui/gameplay-programmer | 2.5 | S3-01 (glyph anchor), S3-02 (signals) | 7 HUD stories pass ACs; AP counter (dominant, snap-tick), produce control, win/loss screen wired |
| S3-05 | **Close 3 build-seams** (scope §8): `selection_changed` emit (CAI addendum) · occupant clickable-region authoring owner · live `GameState.entities()` → BoardRenderer feed owner | technical-director → programmer | 0.5 | S3-01, S3-02 | All 3 seams implemented + owned; detail panel + on-board occupants driven by real live state |
| S3-06 | **Representative Neon Retro-Future art** — 5 entities (HQ, Scout, Trooper, Heavy, Production Outpost) + 2 terrain tiles (base + cover), per `design/assets/entity-inventory.md` stubs | art-director → technical-artist | 3 | entity-inventory (done), S3-08 spikes | Sprites (base + glow-mask; 4 facings for units) + terrain tiles at representative quality; passes the §5.2 solid-black-silhouette test; iso-legibility-testable |
| S3-07 | **QA plan** for the VS build (`/qa-plan sprint`) | qa-lead | 0.5 | this plan | `production/qa/qa-plan-sprint-3.md` exists; test type classified per story |
| S3-08 | **Art/tech de-risk spikes** (AD sign-off watch-items #3/#4): Boom-cyan vs Dark-Stage hue side-by-side test before hex-lock; §8.9 glow-shader 2D per-instance-uniform spike before pipeline commit | art-director + technical-artist | 0.5 | — | Both spikes resolved; hex + shader pipeline confirmed before S3-06 art commits |

### Should Have (Validation — rolls to Sprint 4 if the build consumes the sprint)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S3-09 | **Iso-legibility playtest** (hard gate on Pillar 3) | ux-designer / qa | 0.5 | playable board (S3-01) + art (S3-06) | Documented session in `production/playtests/`; board readable at a glance at shipping camera; silhouettes distinguishable in grayscale; ownership clear by hue |
| S3-10 | **Swing-back playtest** — sampling ≥3 close/undecided + ≥3 decided games + closeout-drag observation | game-designer / qa | 1 | playable loop (S3-02/04) + AI (S3-03) | Documented sessions; ≥1 close game flips via stabilization; no decided game reverses; closeout-drag data captured |
| S3-11 | **VS REPORT + PROCEED/PIVOT/KILL verdict** (`/vertical-slice` build path → `REPORT.md`) | creative-director + producer | 0.5 | S3-09, S3-10 | `REPORT.md` with verdict + velocity log; re-run `/gate-check pre-production` |

### Nice to Have
None. The 4 trimmed stories — CAI-009 (dual-focus/keyboard nav), HUD-008 (audio dispatcher),
AI-007 (fuzz corpus), AI-008 (perf-budget assertion) — are **deferred to Production hardening**,
not this sprint (per `scope.md` §4).

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| None | Sprint 2 closed 8/8 (all Must/Should/Nice) | — |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Build volume exceeds one sprint (~18 est-days vs 8 available) | High | High | Sprint 4 is the sanctioned contingency (scope §9); Day-3 sunk-cost checkpoint; playtests + verdict (S3-09/10/11) may roll to Sprint 4 |
| iso-picking / render breaks in the real project scene (cleared only in the QQ/ADR-0013 spike) | Medium | High | BR Story 002/003 re-confirm in the real scene early; buggy engine `local_to_map` avoided by custom inverse-projection math |
| Representative art is the long pole (its quality gates the legibility test) | Medium | High | S3-08 spikes de-risk hue + shader first; flat-neon silhouette-first is forgiving to produce; VS is symmetric so the 2 faction-hue variants share silhouettes (no 3× cost) |
| Playtester availability for swing-back sampling (≥3 close + ≥3 decided) | Medium | Medium | Self-test + team rotation (scope §9); think-aloud protocol; async Loom/OBS option |
| Cross-workstream integration (BR→CAI→HUD signal seams) | Medium | Medium | S3-05 closes the 3 named seams explicitly; build sequence BR → CAI → HUD keeps producers ahead of consumers |

## Dependencies on External Factors
- None. All Foundation + Core logic is complete and headless-tested in-repo; the VS build is
  Presentation + minimal AI on proven logic.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-3.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
- [ ] A playable VS build is demonstrable end-to-end (move/attack/produce → resolve → win-check → AI reply)
- [ ] At least one documented playtest session logged in `production/playtests/` (iso-legibility and/or swing-back), with a `REPORT.md` verdict (final verdict may complete in Sprint 4)

---

## Origin
Planned 2026-07-27 immediately after the Sprint 2 close-out + retrospective. Sprint 2 (planning +
de-risking) cleared the four Pre-Prod → Production gate CONCERNS at the planning level; Sprint 3 is
the **build** that clears the gate's true blocker — a built + playtested Vertical Slice. Scope,
backlog, UX specs, art sign-off, and entity inventory are all in place (Sprint 2 deliverables).

> **Scope check:** run `/scope-check` if any story is added beyond the 26 in-slice stories the
> VS scope names — the slice's whole discipline is *cut content, not quality*.

> **QA plan:** none exists yet — S3-07 covers it. Run `/qa-plan sprint` **before implementation
> begins** so stories are built against test specs, not a blank slate.
