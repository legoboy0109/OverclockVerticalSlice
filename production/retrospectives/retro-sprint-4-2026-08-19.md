## Retrospective: Sprint 4 — Vertical Slice Validation
Period: 2026-07-29 -- 2026-08-12 (art track ran on to 2026-08-19)
Generated: 2026-08-19

### Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Tasks | 10 | 4 in-window (5 incl. post-window art) | −6 |
| Completion Rate | — | **40%** in-window · 50% incl. art | — |
| Must-Have tasks | 6 | **1** in-window (S4-01) | −5 |
| Committed scope (must + should) | 8 available | **9.0** (must 7 + should 2) | **+1.0 (+12.5%) before work started** |
| Full task list | 10 total days | **10.5** (incl. 1.5 nice-to-have) | +0.5 (+5%) |
| Unplanned work added | 0 | AP→AP+Credits pivot, Phases 1–6 (~4 days) | +4 |
| Committed load incl. unplanned | 8 available | **13.0** | **+62%** |
| Commits (in window) | — | 15 | — |
| Test suite | — | 830 → 860 passing | +30 |

### Velocity Trend

| Sprint | Planned | Completed | Rate |
|--------|---------|-----------|------|
| Sprint 1 (Foundation) | 7 | 7 | 100% |
| Sprint 2 (VS Enablement) | 8 | 8 | 100% |
| Sprint 3 (VS Build) | 26 stories + 7 tasks | 26 stories + 1 bonus / 1 task | 100% build · ~14% sprint-tasks |
| Sprint 4 (VS Validation) | 10 | 4 | **40%** |

**Trend**: Decreasing, but the headline rate hides the real signal. The split Sprint 3 named held
exactly: **everything an agent session can do headlessly got done; everything requiring a human at
a display did not.** All four in-window completions (S4-01, S4-08, S4-09, S4-10) were
agent-completable. All four human-gated tasks (S4-04/05/06/07) scored zero, for the second sprint
running.

### What Went Well

- **The de-risk-first sequencing worked.** S4-01 ran on day 1 exactly as Sprint 3's action item #1
  prescribed, and it paid off twice: Boom `#22C7F0` was locked with numbers (worst-case ΔE2000 51.8,
  WCAG 5.19:1, grayscale Δ104) and the 2D per-instance-uniform shader approach was confirmed before
  any art depended on it.
- **The unplanned economy pivot was executed to a high standard.** Six phases, 9 GDDs, 13 ADRs, the
  TR registry, config, engine, HUD and tests — all cross-consistent and committed. It was the wrong
  thing to do *during this sprint*, but it was not done badly.
- **The art track, once it ran, produced durable infrastructure rather than just assets.** Eight
  committed pipeline tools (`cutout` with deshadow/pockets, `recolor`, `make_facings`,
  `place_runtime`, `glow_mask`, `state_variant`, `draw_plain_tile`, `draw_cover_tile`) make every
  hue variant, facing, mask, state and tile **regenerable from a master**. A future art change is
  now a re-run, not a redo.
- **Two real spec defects were caught before they reached the gate**: unit armour was specced at
  `#232A38`, the exact value of the terrain tile (units were invisible on the board), and role
  separation needed body-plan changes rather than proportion adjectives. Both would have failed the
  S4-04 legibility gate after all the art was produced.
- **Technical debt stayed flat** at 5 TODO / 0 FIXME / 0 HACK while the suite grew 830 → 860.

### What Went Poorly

- **The human-gated track scored 0/4 for the second consecutive sprint**, and Sprint 3's fix for
  exactly this was already in place (see Follow-Up below). This is the sprint's defining failure.
- **The plan was over-committed before it began.** Measured consistently — committed scope
  (must + should) against the 8 *available* days — Sprint 4 committed **9.0 (+12.5%)**, and its
  full list of 10.5 exceeded even the 10-day total. Nice-to-haves ride the buffer and are not
  commitments, which is why the committed figure is the one that matters.
- **~4 days of unplanned pivot work were absorbed without descoping anything**, taking committed
  load to **13.0 against 8 available (+62%)**. No task was cut, no re-plan was issued, and the
  sprint plan quietly became fiction rather than being corrected.
- **S4-02's 3-day art estimate modelled the wrong kind of work.** It was estimated as a production
  task; it behaved as an iterative art-direction loop — roughly seven user decisions, two spec
  amendments, and 39 generations on infantry alone. It finished 7 days past the window.
- **S4-05 never ran despite being unblocked the entire time.** It required no art, was marked
  `ready-for-dev`, and the plan itself said it was runnable in parallel. Nothing consumed it.

### Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| S4-02 art blocked S4-03/04/07 | Whole sprint + 7 days | Art completed 2026-08-19 | Was correctly identified as the critical path in Sprint 3's action #1 — the sequencing was right; the *estimate* was wrong |
| Unplanned economy pivot displaced the validation half | ~4 days mid-sprint | Completed and committed | Route mid-sprint design changes to a post-gate backlog; require an explicit re-plan to accept them |
| Human-gated playtests had no scheduled session | 2 sprints | **Still unresolved** | Book a calendar session, not a priority label (see Action #1) |
| Bare SDXL cannot rotate a design or hold frames | Discovered during art | Facings reduced to master + mirror; states reframed as renderer transforms | Check tooling capability before speccing per-facing/per-frame asset counts |

### Estimation Accuracy

| Task | Estimated | Actual | Variance | Likely Cause |
|------|-----------|--------|----------|--------------|
| S4-02 representative art | 3 d | ~3 d effort across 21 calendar days | **+7 days schedule** | Estimated as production; is actually an approval-loop with iteration rounds. Calendar cost ≠ effort cost when every round needs a human decision |
| S4-08 occupant pick-region | 1 d | 1 d | 0 | Well-scoped, agent-completable |
| S4-09 code follow-ups | 0.5 d | 0.5 d | 0 | — |
| S4-10 HUD chrome UX pass | 1 d | 1 d | 0 | — |
| S4-04/05/06/07 | 3 d total | not started | n/a | Not an estimation failure — a scheduling failure |

**Overall estimation accuracy**: every agent-completable task landed within ±0% of estimate (4/4).
Every miss was either a human-gated task that never started, or an art task whose *calendar* cost
was mis-modelled. **We do not have an estimation problem on agent work; we have a scheduling
problem on human work.**

### Carryover Analysis

| Task | Original Sprint | Times Carried | Reason | Action |
|------|----------------|---------------|--------|--------|
| Iso-legibility playtest | s3-09 → S4-04 → S5-03 | **2** | Blocked on art (S3), then never scheduled (S4) | Complete — now genuinely unblocked |
| Swing-back playtest | s3-10 → S4-05 → S5-04 | **2** | **Never blocked. Never scheduled.** | Complete — book a session (Action #1) |
| VS REPORT + re-gate | s3-11 → S4-06 → S5-05 | **2** | Depends on both playtests | Complete once the two above run |
| Entity sprite feed | s3-05 → S4-03 → S5-01 | **2** | Genuinely blocked on art both times | Complete — art landed 08-19 |
| Advisory visual sign-offs | S4-07 → S5-07 | 1 | Blocked on art | Complete |

Three items have now been carried twice. Two of the three were **never technically blocked**.

### Technical Debt Status
- Current TODO count: **5** (previous: 5 — Sprint 2)
- Current FIXME count: **0** (previous: 0)
- Current HACK count: **0** (previous: 0)
- Trend: **Stable/flat** while the suite grew 830 → 860 tests
- No areas of concern. Debt is not this project's problem; scheduling is.

### Previous Action Items Follow-Up

| Action Item (from Sprint 3) | Status | Notes |
|-----------------------------|--------|-------|
| 1 — Run de-risk spikes first, then produce art | **Partly done** | Spikes ran day 1 as intended ✅. Art started but finished 7 days past the window |
| 2 — Execute both playtests + write REPORT + re-gate | **Not started** | Zero sessions run. Rolls to Sprint 5 |
| 3 — Close the two build-seams | **Partly done** | s4-08 click-select landed 08-05 ✅; the entities feed stayed blocked on art |
| 4 — Change delegation policy (implement directly; reserve sub-agents for parallel work + review) | **Done** | Followed through the pivot and art track |
| 5 — Split the board into agent-completable vs human-gated tracks so validation stops being silently deferred | **Done in planning, FAILED in execution** | Sprint 4 does mark ★ on every human-gated task and its capacity note says it front-loads them — **and the track still scored 0/4.** The fix was implemented as *labelling*, and labelling was not the constraint |

### Action Items for Sprint 5

| # | Action | Owner | Priority | Deadline |
|---|--------|-------|----------|----------|
| 1 | **Book a specific play session for S5-04 (swing-back) before any S5-01 code begins.** A calendar commitment, not a priority label — the label has failed three sprints running. It needs no art and runs on the current build today | user (game-designer) | **High** | S5 day 1–2 |
| 2 | **Never commit above available days** — measured as **must + should vs the 8 available days**, with nice-to-haves riding the 2-day buffer rather than counting as commitments. Sprint 4 committed 9.0 against 8 (+12.5%). Sprint 5 commits exactly 8.0 (must 5 + should 3) — hold that line | producer | High | S5 planning ✅ already applied |
| 3 | **Mid-sprint design changes go to a post-gate backlog.** Accepting one mid-sprint requires an explicit re-plan that descopes something and records the trade. The pivot was absorbed silently and the plan became fiction | producer + creative-director | High | S5 kickoff |
| 4 | **Estimate human-gated art as an approval loop, not a production task.** Model the number of decision rounds, and treat calendar cost as distinct from effort cost | art-director + producer | Med | next art estimate |

### Process Improvements

- **Human-gated work needs a booked session, not a priority flag.** This is the single lesson of
  Sprint 4. Sprint 3 correctly diagnosed the split and correctly prescribed separating the tracks —
  and the human-gated track *still* scored zero, because separating and labelling a track does not
  cause anyone to sit down and play. Sprint 5 should not be considered planned until a session
  exists for S5-04.
- **Unplanned work must trade against planned scope, visibly.** Absorbing ~4 days without cutting
  anything is what turned a 12.5%-over plan into a 62%-over one. If something comes in, something
  goes out, and the swap gets recorded.
- **Keep investing in regenerable pipelines.** The art tooling turned a one-off asset drop into a
  system where any hue, facing, mask, state or tile can be rebuilt from a master by re-running a
  script. That investment is why the late-arriving spec amendments cost hours instead of days.

### Summary

Sprint 4 delivered real, durable value — a complete economy pivot, the entire art track, and eight
pipeline tools — while completing only 40% of what it planned and **0% of the validation work it
existed to do**. The gate it was created to clear is no closer than when Sprint 3 ended.

The single most important thing to change: **stop treating human-gated validation as a prioritisation
problem and start treating it as a scheduling one.** Sprint 3 diagnosed the split correctly and its
fix was faithfully implemented — as a label — and the result was identical. Sprint 5 has exactly two
playtests standing between the project and its PROCEED/PIVOT/KILL verdict, and one of them has been
runnable on the current build, unblocked, for three sprints.
