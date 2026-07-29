## Retrospective: Sprint 3 — Vertical Slice Build
Period: planned 2026-07-28 → 2026-08-08; **executed 2026-07-27 → 2026-07-28** (compressed, agent-augmented)
Generated: 2026-07-28

> **Framing:** Sprint 3 is the project's first *implementation* sprint and the true
> Pre-Production → Production gate. It has two halves: (A) build a playable, rendered VS
> loop; (B) validate it via the iso-legibility + swing-back playtests → a PROCEED/PIVOT/KILL
> verdict. Half A is complete; Half B has not started.

---

### Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| In-slice stories | 26 | **26 done (100%)** + 1 bonus (hud-008) | +1 |
| Sprint-level tasks | 7 (4 build + 3 validation) | 1 done (QA plan), 3 deferred→S4 (sanctioned), 3 build-tasks open | −6 |
| Story effort delivered | ~18.25 est-days total | ~12.75 est-days done (all code build) | ~5.5 d open (art/spikes/playtests) |
| Bugs found | — | ~4 (all in-sprint, review-caught) | — |
| Bugs fixed | — | 4 (**0 escaped**) | — |
| Unplanned work added | — | VS integration glue (scene assembly, runnable root, keyboard cursor, gameplay verbs) + hud-008 | — |
| Commits | — | 33 (27 `feat`, 3 `docs`, 3 `chore`) | — |
| Test suite | 177 S1/S2 baseline holds | **811/811 green**, 0 failures, 0 orphans, 74 suites | +634 |

### Velocity Trend

| Sprint | Planned | Completed | Rate |
|--------|---------|-----------|------|
| Sprint 1 (Foundation) | 7 | 7 | 100% |
| Sprint 2 (VS Enablement, planning) | 8 | 8 | 100% |
| Sprint 3 (VS Build) | 26 stories + 7 tasks | 26 stories +1 bonus / 1 task | **100% build · ~14% sprint-tasks** |

**Trend**: The *code* throughput held at 100% and jumped an order of magnitude in volume (26
implementation stories + 4 integration-glue features + 634 tests in one compressed session).
But the sprint-task completion rate reveals the real story: **everything an agent session can do
headlessly got done; everything requiring art or a human-at-a-display did not.**

### What Went Well
- **The entire code build shipped, green, in one compressed session.** All 26 in-slice stories
  across 4 epics (Board Renderer 5/5, CAI 8/8, AI 6/6, Game HUD 7/7) + a bonus hud-008 audio
  dispatcher pulled forward from Production. 811/811 tests pass, 0 orphans, boots clean headless.
- **The slice is genuinely playable end-to-end** — `produce → move/attack → build → end turn →
  AI responds` — proven by the `vertical_slice_boot_test` suite, not just claimed.
- **Independent review caught real, shipping-blocking bugs.** The `AITurnDriver` coroutine
  no-`await` race (overlapping AI turns, passing only by timing luck), the produce
  "only-first-producer / at-cap-not-skipped" bug, and the ai-006 AC-9 non-termination hang were all
  caught by review/instrumentation and fixed **in-sprint — zero escaped to QA.** Review discipline
  is paying for itself.
- **Working around a blocked seam instead of stalling.** Mouse click-select is blocked on unbuilt
  occupant pick-regions, so the loop was wired to a keyboard board-cursor using public APIs only —
  a fully playable slice was delivered *around* the blocker rather than waiting on it.
- **The Pass-Through Invariant held.** A whole Presentation + AI layer landed on top of
  Foundation/Core with no lower-layer regressions — the architecture's central bet is validated in
  practice.

### What Went Poorly
*(Systemic causes, not blame.)*
- **The sprint's actual reason for existing — the validation gate — did not happen.** S3-09
  (iso-legibility playtest), S3-10 (swing-back playtest), S3-11 (REPORT + verdict) are all still
  `backlog`. The VS exists to produce a PROCEED/PIVOT/KILL verdict; that verdict does not yet exist.
  It's *sanctioned* to roll to Sprint 4, but it's the headline gap.
- **Art is the critical-path bottleneck and never started.** S3-06 (representative art, 3 est-days,
  the single biggest line item) is blocked on S3-08 (de-risk spikes), which is blocked on nothing but
  never ran. No art → the iso-legibility playtest (a **hard Pillar-3 gate**) cannot run. The build
  renders placeholder diamonds.
- **Everything visual/feel needs a windowed human, and this was a headless session.** Every advisory
  Visual/Feel sign-off (br-002/003/005, cai-006, hud-004/005/007) is deferred for the same reason.
  The validation half is structurally un-completable by a headless agent loop — and that wasn't
  separated out in planning.
- **Sub-agent truncation recurred chronically** — on essentially every CAI and AI story — *despite*
  being Sprint 2's action item #1. The verify-on-disk-and-finish-myself workaround worked but is a
  persistent efficiency drag; for small greenfield stories, dispatching an agent was slower than
  implementing directly.

### Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| Playtests (S3-09/10) blocked on art (S3-06) blocked on spikes (S3-08) | Whole sprint, unresolved | None yet — chain never started | Run S3-08 spikes on day 1 of S4; art is critical path |
| Validation half needs a windowed human; session is headless | Whole sprint | In progress — pulling build to a display PC | Plan human-gated work as its own track, not interleaved with agent code work |
| Mouse click-select blocked on unbuilt occupant pick-regions (seam c) | Whole sprint | Worked around with keyboard cursor; seam still open | Close build-seams (b)/(c) in S4 |
| Chronic sub-agent result truncation | Every CAI/AI story | Verify-on-disk + finish/review myself | Implement small stories directly; reserve agents for parallel/large work + review |

### Estimation Accuracy
Per-task ±20% is low-signal again — the work ran in a compressed agent-augmented session, not the
planned 10-day window. The **useful** signal: the ~12.75 est-days of *code* work compressed to a
single session, while the ~5.5 est-days of *art + spikes + playtests + verdict* did **0%** — because
that work is human-/windowed-gated, not agent-completable. The estimation lesson isn't variance; it's
that planning should **split agent-completable code work from human-gated validation/art work** so the
latter isn't silently absorbed and deferred every sprint.

### Carryover Analysis

| Task | Origin | Times carried | Reason | Action |
|------|--------|---------------|--------|--------|
| Close 3 build-seams + AD watch-items | S2 action #4 | 2 | Rolled into S3-05/S3-08, never executed | Close in S4 (seam (a) `selection_changed` *did* land w/ HUD facade; occupant-region + live entities-feed remain) |
| De-risk spikes (S3-08) | S3 | 1 | Never started; blocks art | **Day-1 of S4** |
| Representative art (S3-06) | S3 | 1 | Blocked on spikes | S4 critical path |
| Iso-legibility + swing-back playtests (S3-09/10) | S3 | 1 | Blocked on art + windowed human | S4 (sanctioned) |
| VS REPORT + verdict (S3-11) | S3 | 1 | Blocked on playtests | S4 (sanctioned) |

### Technical Debt Status
- TODO: **5** · FIXME: **0** · HACK: **0** (all in `src/`)
- Trend: **Stable** on raw counts (unchanged since S2), but the **tech-debt register grew to ~40
  tracked entries** — mostly deferred visual sign-offs, ADR footnotes, and unpinned input bindings
  logged honestly during the build rather than dropped. Not alarming, but worth a triage pass before
  Production.

### Previous Action Items Follow-Up

| Action (Sprint 2) | Status | Notes |
|---|---|---|
| #1 Sub-agents return full artifact / write incrementally | **Not effective** | Truncation recurred chronically; needs a different approach (below) |
| #2 `/consistency-check` during scoping | N/A this sprint | No new scope doc in a build sprint; carry forward |
| #3 Reconcile sprint dates with reality | Partially done | S3 dated 07-28/08-08 but executed 07-27/28 — still ahead of paper |
| #4 Close build-seams + AD watch-items before S3 build | **Not done** | Became S3-05/S3-08, still open — the notable unaddressed carryover |
| #5 Log v1 retention risk before Alpha scope lock | Not yet due | Deadline is Alpha scope lock (future) |

### Action Items for Sprint 4

| # | Action | Owner | Priority | Deadline |
|---|--------|-------|----------|----------|
| 1 | Run the S3-08 de-risk spikes (Boom-cyan hue test; glow-shader 2D/uniform) **first**, then produce S3-06 representative art (5 entities + 2 tiles) — this is the critical path that unblocks everything visual | art-director + technical-artist | High | S4 day 1–3 |
| 2 | Execute both playtests (iso-legibility hard gate + swing-back sampling) on a windowed build and write `REPORT.md` with the PROCEED/PIVOT/KILL verdict + re-run `/gate-check pre-production` | creative-director + producer + qa | High | S4 |
| 3 | Close the two open build-seams — occupant clickable-region authoring + live `GameState.entities()`→BoardRenderer feed — to enable real mouse click-select and occupant sprites | technical-director | Med | S4 |
| 4 | Change delegation policy: implement small greenfield stories **directly**; reserve sub-agents for genuinely parallel/large work + **independent review** (which earned its keep catching 3 blocking bugs) | orchestration / process | Med | S4 kickoff |
| 5 | In S4 planning, **split the board into agent-completable vs human-gated tracks** so validation/art work gets its own capacity and stops being silently deferred | producer | Med | S4 planning |

### Process Improvements
- **Split agent-completable code work from human-gated art/validation work in the plan.** The
  recurring pattern is code = 100%, human-gated = 0%; make that visible in capacity so the validation
  half is scheduled, not absorbed.
- **Front-load the de-risk spikes** (the S2 lesson that worked) — apply it to S3-08 so art isn't
  blocked on day 1 of S4.
- **Default to direct implementation for small stories; keep independent review mandatory.** Review
  caught every blocking bug this sprint; agent *implementation* of small stories was a net drag.

### Summary
A high-throughput build sprint that **fully delivered its risky half** — 26 stories, a bonus, 811
green tests, a genuinely playable end-to-end loop, and three shipping-blocking bugs caught before QA.
But the sprint's *raison d'être*, the PROCEED/PIVOT/KILL verdict, is not reached: it's gated behind
art (blocked on unstarted spikes) and playtests (blocked on art + a windowed human). The single most
important change going forward is **treating human-gated validation/art as its own scheduled track**
(action #5) so the gate the vertical slice exists to pass actually gets run — starting with the S3-08
spikes on day 1 of Sprint 4.
