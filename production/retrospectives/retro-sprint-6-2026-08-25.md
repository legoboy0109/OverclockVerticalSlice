## Retrospective: Sprint 6 — Prove the PIVOT Fix
Period: 2026-08-24 -- 2026-08-25 (planned window was 2026-08-25 -- 2026-09-08)
Generated: 2026-08-25

> **The sprint achieved its one goal: the S6-06 gate passed.** It also delivered roughly four
> times its committed scope without ever re-planning, and its own tracking artifacts stopped
> recording two-thirds of the way through. Both halves of that sentence are the retro.

### Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Tasks | 10 (S6-01…S6-10) | **38** (S6-01…S6-38) | **+28 (+280%)** |
| Completion rate — planned scope | — | **100%** (10 of 10) | — |
| Must-Have tasks | 6 | **6** | 0 |
| Committed scope (must + should) | ~8 days available | 7.5 days | −0.5 (within rule) |
| Unplanned work absorbed | 0 | **28 items** | **+28, with no re-plan and no recorded trade** |
| Commits (first-parent) | — | 24 | — |
| Files changed | — | 364 (+25,123 / −1,842) | — |
| Test suite | 984 baseline | **1,233** | **+249** |
| Suites | 89 | 106 | +17 |
| ⛔ **The gate** | pass 4 of 4 conditions | **passed 4 of 4** | ✅ |

### Velocity Trend

| Sprint | Planned | Completed | Rate |
|--------|---------|-----------|------|
| Sprint 1 (Foundation) | 7 | 7 | 100% |
| Sprint 2 (VS Enablement) | 8 | 8 | 100% |
| Sprint 3 (VS Build) | 26 stories + 7 tasks | 26 stories + 1 bonus / 1 task | 100% build · ~14% sprint-tasks |
| Sprint 4 (VS Validation) | 10 | 4 | **40%** |
| Sprint 5 (Renderer + validation) | 10 | 6 | **60%** |
| Sprint 6 (Prove the fix) | 10 | **10 planned + 28 unplanned** | **100% of plan · 380% of scope** |

**Trend**: the two-sprint slide reversed hard — but read the number carefully. **380% is not a
velocity achievement, it is a planning failure with a good outcome.** The right reading is that the
sprint plan became obsolete on day one when the gate passed early, and nothing replaced it.

★ **And the split that dominated Sprints 3–5 finally broke.** For three sprints running, *everything
an agent could do headlessly got done and everything needing a human at a display did not.* This
sprint closed both human-gated items — **not by getting a human, but by discovering most of the work
was scriptable.** See "What Went Well" #2.

---

### What Went Well

**1. ★★ The measure-don't-predict discipline, and it is the sprint's most transferable output.**
Four levers were tried against the gate. **Three of them each found and fixed a genuine defect and
moved resolution not at all** — bounding the economy (the change the PIVOT report itself prescribed
as *the* fix), implementing `CREDIT_TO_AP_RATE` (which turned out never to have existed outside doc
comments), and valuing production capacity. The two that worked were about **incentives, not
correctness**: production cooldowns, and `hq_siege_value` 12 → 60.

> ★ **A correct system that rewards the wrong thing plays exactly like a broken one.** Every defect
> the first three levers found was real. Fixing all of them changed nothing a player would notice.
> **Four predictions were made this sprint and one landed** — and both of the two that worked were
> the user's suggestions, not mine.

**2. ★★ Two items carried as "blocked on the user" for four sprints turned out to be mostly
scriptable.** S5-03 and S5-04 had rolled over three times each on the belief that they needed a
human at a display. `tools/CaptureLegibility.tscn` + `analyse_legibility.py` answer **5 of S5-03's
6 measurements** with no human at all; `analyse_swing.py` answers both of S5-04's stated
requirements. What genuinely needs a person shrank from two whole playtests to **one ~20-minute
observer session and three feel questions.**

> ⇒ **The blocker was never really the human — it was that nobody had asked which *parts* needed
> one.** Re-examine anything labelled "blocked on the user" for the half a script can do. This is
> now an action item.

**3. Tooling kept being the thing that found the truth.** Every significant defect this sprint was
found by building something that could actually *look* at the game: `DiagnoseAI` found the real
cause after three hypotheses failed; `DiagnoseCliff` produced the trace that turned "the game
snowballs" into "four units on a spawn ring latch a player out permanently"; `CaptureSlice` and
`CaptureLegibility` found bugs a green 1,000-test suite had never flagged. **This is the second
sprint running where that was true, and it should stop being a pleasant surprise.**

**4. The slice became honestly playable, which it had not been.** At verdict time the slice had an
invisible cursor, "buttons" that were `draw_string` calls no input could activate, costs labelled in
the wrong currency, and move-range highlights painted underneath the board. S6-17…S6-30 fixed all of
it and added the three missing screens. ★ **The vertical slice had been declared "playable" on the
strength of a green test suite and a code read.**

**5. Every risk the plan named actually fired, and the mitigations worked.** "The batch does not
flip" (mitigated by running it after S6-02 and S6-04, not only at S6-06 — which is exactly how the
three failed levers were caught cheaply). "AI re-anchor is subtler than estimated" (it was: the rate
had never been implemented). "Scope drift toward factions" — **held completely; not one faction item
was touched.** ★ **The one risk that fired and had no mitigation was the one not on the list.**

---

### What Went Badly

**1. ⛔⛔ The tracking artifacts stopped at S6-10 while the work ran to S6-38.** `sprint-6.md` and
`sprint-status.yaml` recorded nothing after the Factory re-stat. Twenty-eight further items —
including the legibility budget, both playtests, a rules change, three whole screens, and the
contextual action menu — existed only in design docs, the post-gate backlog and session state.

The sprint's own Definition of Done says *"No unplanned work absorbed without a recorded descope
trade."* **It was absorbed without either.** Nothing was lost, but for a week the sprint record said
something false about the sprint.

> ★★ **The mechanism: tracking stopped at exactly the moment the gate passed.** The plan had a
> finish line, the work did not, and nothing prompted a re-plan. **A sprint plan whose scope is
> overtaken mid-flight needs re-planning, not silent extension.**

**2. ⛔ A stale warning was carried forward through a merge banner and would have mis-briefed every
future session.** The session-state banner written *after* the gate passed still said the gate was
"HONESTLY FAILED at 2 of 4 conditions" — copied verbatim from the pre-pass banner. Any session
picking up cold would have started by re-attacking a solved problem.
> ⇒ **A carried-forward warning is not re-verified by being carried forward.** Corrected at
> close-out, with the correction stated rather than the text quietly swapped.

**3. ★★ Four dead hooks found in two days — implemented, documented, tested, never called.**
`CommandInterface.notify_action_applied` (ADR-0015 §3's specified hook), `GameHud.open_ap_preview()`
(a seam `game-hud.md` calls RESOLVED), `BoardCursor.jump_to_next()` (declared in `project.godot`
since the ADR-0014 spike), and the whole `VerticalSliceRoot._draw()` overlay path.

> ★ **Same cause every time: a unit test proves a function works, not that anything invokes it.**
> And the design docs actively concealed it — three of the four are described in an Approved
> document as done. **Grep for callers of any API a design doc calls "resolved".**

**4. ★ At least four tests were asserting the bug.** The hp glyph test asserted `Vector2(0,0)` — the
authored value that put the readout behind the sprite. A movement test's *name* described the
intent while its assertion pinned the defect. A deploy test was rejecting on `POPULATION_CAP_REACHED`
before ever reaching the check it claimed to exercise. An income test asserted gross where net was
now correct.
> ⇒ **A test whose name contradicts its assertion is worth reading twice**, and green is not the
> same as right.

**5. Two specs were written after the thing they specify.** The Settings screen shipped with no UX
spec at all; the spec came two commits later and its review then found **a real bug** (all four
`save()` call sites discarded the returned `Error`, so an unwritable `user://` lost the player's
settings silently). ★ **Three of that review's four blocking issues had never been *decided*, only
never *noticed*** — which is precisely what a pre-implementation review catches on paper for free.
The retroactive banner was kept on the spec after approval, correctly: approval closes the gap, it
does not undo the ordering.

**6. A production class was defined under `tests/`.** `Structure` — called by `GameState.start_turn`
on every single turn. It worked in-editor and headless because `class_name` is project-global, and
**would have crashed on the first turn of any export that excludes `tests/`.** Found incidentally.

**7. The estimate model failed in a way worth naming.** S6-02 was estimated for the feature; the
feature was the small part. What overran was everything the ×100 Credit rescale touched — a
conversion constant, a rounding function, unrescaled data files, and underfunded test fixtures.
★ **Categories 1 and 2 are invisible to grep and to the compiler.** A rescale is not done when the
code compiles; it is done when every quantity in that unit has moved *and* every constant that
converts or rounds between units has been re-derived.

---

### Action Items

| # | Action | Owner | Trigger |
|---|---|---|---|
| **1** | ★★ **Re-plan, don't silently extend.** When a sprint's gating goal is met early, close the plan and write the next one rather than appending unnumbered work. Concretely: if ≥3 unplanned items land, `/sprint-plan` runs again before a 4th | producer | Any sprint |
| **2** | ★★ **Re-examine every "blocked on the user" item for the half a script can do.** Two four-sprint blockers dissolved this way. Apply it to the three remaining ones *before* booking a human session | producer | Sprint 7 planning |
| **3** | ★ **Grep for callers of any API a design doc calls "resolved" or "done".** Four dead hooks in two days, three of them documented as complete. Make this a step in `/story-done` | lead-programmer | `/story-done` |
| **4** | ★ **Grep for production symbols whose only definition lives under `tests/`.** One found; the class of bug is silent until export | lead-programmer | Before any export build |
| **5** | **Run an export build.** Nothing in six sprints has ever exported, which is why #4 was invisible. A single headless export would have caught it | devops-engineer | Sprint 7 |
| **6** | **Write the spec before the screen.** The Settings ordering produced a real data-loss bug that a paper review would have caught free | ux-designer | Any new screen |
| **7** | **Fix or retire the two unrunnable smoke checks.** Performance items 16/17 have returned "not measured" in every smoke report because no target-hardware baseline exists | technical-director | Sprint 7 |
| **8** | ★ **Audit conversion and rounding constants first after any rescale.** Neither `CREDIT_TO_AP_RATE` nor `UPKEEP_DIVISOR` was findable by grepping stale names | gameplay-programmer | Any unit rescale |

### Carried Process Debt

- **Sprint 4's retro action "start the validation half on day 1, in parallel"** — finally honoured,
  though by accident: S5-03/S5-04 ran because the gate passed early, not because they were
  scheduled first.
- **The `.agent/notes.md` wrong-entry incident** (a note claiming a runner pass rebuilds the global
  class cache; it does not, and with the cache deleted the runner **hangs silently**) cost ~20
  minutes and had survived since 2026-07-28. Corrected. ★ **A wrong note is worse than no note.**

### ⛔ What this sprint did NOT settle

- **The one-unit cliff.** +1 Trooper takes the game from 6.75 lead changes to zero, with no gradient.
  The *latch* underneath it was a defect and is fixed; the cliff itself is a live **design question**
  and it shapes what wave 2 is for.
- **Whether any of it feels like anything.** S5-04's Analysis D — *does spending Credits feel like a
  tempo cost?* — is the two-budget pivot's core hypothesis and has never been tested by a human.
- **S5-03's naive-observer session**, ~20 minutes, without which the Pillar-3 gate is not formally
  passed.
