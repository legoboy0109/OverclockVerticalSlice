# Sprint 8 — 2026-08-26 to 2026-09-09 (Re-verdict and advance the stage)

## Sprint Goal

**Get a fresh PROCEED / PIVOT / KILL verdict on the vertical slice, and re-run the
Pre-Production gate.** Everything a script can measure has been measured. What decides this
sprint is roughly **one hour of a human playing the game.**

> ★ **This sprint is deliberately NOT about building anything.** Wave 2 is designed and waiting;
> the faction corpus is written. None of it should be built until the slice's founding premise
> has been checked by a person, because **Analysis D tests whether the two-budget economy — the
> thing Sprint 4 pivoted the entire project onto — feels like anything at all.**

## Context — why this is the whole sprint

`REPORT.md` returned **PIVOT** on 2026-08-24. Addendum A (S6-06 close-out) records that four of
`scope.md` §10's five PROCEED criteria are now met:

| §10 PROCEED criterion | Status |
|---|---|
| Full loop completed unguided | ✅ MET, and materially strengthened since the verdict |
| Built within the time box at representative quality | ✅ MET |
| Iso-legibility PASS | ◐ **CONDITIONAL** — 5 of 6 measurements pass, blocking defect fixed. Owes the observer session |
| Swing-back PASS | ✅ Passes both stated requirements |
| **Tempo fantasy is felt** | ⛔ **UNTESTED** — the only criterion no script can reach |

★ **The validation half has now rolled six sprints.** Sprint 6 proved most of it was scriptable
and closed those parts; what is left is genuinely irreducible.

---

## ⛔ The critical path — S8-01, and it needs the user

Everything else in this sprint is either preparation for it or waits on it.

### S8-01 — the play session (~1 hour, one sitting)

Two owed sessions, and they can be run back-to-back on the same build.

**Part 1 — S5-03 naive/silent observer (~20 min).** Needs **one person who has not seen the
game**. You run it; they watch and answer. Three questions, unprompted:

1. Within 2 minutes, can they say **which units are theirs**?
2. Can they tell **which units have already moved**?
3. Do they read the structures as **buildings** rather than large units?

⚠ Do not explain the game first. The measurement *is* whether it explains itself.

**Part 2 — S5-04 Analyses A / C / D (~40 min).** You play, ideally a close game.

| | Question |
|---|---|
| **A** | Does the swing feel **alive** — do you notice the lead changing, and does the game feel yours to lose? |
| **C** | Does tempo read **at a glance** — can you tell your AP/Credit position without stopping to work it out? |
| **D** | ★★ Does spending Credits **feel like a tempo cost** — deliberate, or fiddly bookkeeping? |

> ★★ **D is the one that matters.** Sprint 4 split one budget into two on the premise that paying
> a tempo price for economic investment would feel *deliberate*. Every measurement since has
> confirmed the mechanism **works**. None has tested whether it **feels** like anything, and the
> whole economy rests on it.

**How to run it** — a real exported binary now exists (S7-05):

```
./builds/linux/Overclock.x86_64          # or: ./redot   (runs from the editor)
```

New Skirmish from the main menu. ⚠ If the binary is stale, rebuild:
`./redot --headless --export-release "Linux Release" "$PWD/builds/linux/Overclock.x86_64"`

---

## Tasks

### Must Have — the critical path

| ID | Task | Owner | Est. | Deps | Acceptance |
|----|------|-------|-----:|------|------------|
| ✅ **S8-00** | **Prepare the session** — a single ready-to-fill file with all six questions, room for notes, and no set-up required from the user | producer | 0.25 | — | The user opens one file, plays, and writes prose. No form-filling, no protocol to read first |
| ⛔ **S8-01** | **The play session** — S5-03 observer + S5-04 Analyses A/C/D | **user** | 1.0 | S8-00 | Six questions answered in the user's own words. Partial is fine and still unblocks the verdict |
| **S8-02** | **Analyse and write up** — turn the notes into findings against the S5-03 and S5-04 reports | qa-lead | 0.5 | S8-01 | Each of the six questions has a recorded answer and a PASS / CONCERN / FAIL |
| **S8-03** | ⛔ **`/vertical-slice` re-verdict** — a fresh PROCEED / PIVOT / KILL against `scope.md` §10 | producer + creative-director | 0.5 | S8-02 | All five criteria assessed with evidence. `REPORT.md` gains a new verdict section; the PIVOT stays as history |
| **S8-04** | ⛔ **`/gate-check pre-production`** | technical-director | 0.5 | S8-03 | PASS / CONCERNS / FAIL with named blockers. ★ A PROCEED here is what advances `production/stage.txt` to Production |

### Should Have — runs while S8-01 is pending

| ID | Task | Owner | Est. | Notes |
|----|------|-------|-----:|-------|
| ✅ **S8-05** | **Accent-coverage check in the asset pipeline** | technical-artist | 0.5 | ★ S5-03's own recommendation #2, still open. The Sniper defect shipped and survived a full art sprint **because nothing measured it**, and every wave-2 unit has the same failure mode available. `analyse_legibility.py` already computes the number |
| ✅ **S8-06** | **Controller glyphs** — the legend names keyboard keys regardless of active device | ui-programmer | 1.0 | Deck Verified gap 1. The bindings all exist; only the *display* is wrong |
| ✅ **S8-07** | **Text legibility at 1280×800** — pick a sensible `ui_scale` default for the floor | ux-designer | 0.5 | Deck Verified gap 2, and the action-menu spec's open advisory. ★ Testable now against the real binary |

### Nice to Have

| ID | Task | Est. | Notes |
|----|------|-----:|-------|
| **S8-08** | Idle power draw — conditional throttle, not `low_processor_usage_mode` outright | 0.5 | ⚠ The glow pulses and motion runs on tweens; sleeping the loop makes both choppy. Wants measuring on device |
| ✅ **S8-09** | Verify Redot/Godot dual-focus parity | 0.25 | **DONE 2026-08-26 — PASS.** `tools/CaptureDualFocus.tscn`, 8/8 checks, deterministic ×3. Closes the ux-review's advisory 4 and GDD OQ-6. ⚠ Opened `action-menu.md` **OQ-7**: hover is close to invisible on its own (~3% lift; `flat` suppresses the hover StyleBox) — a design call, left open. Report: `production/playtests/s8-09-dual-focus-2026-08-26.md` |

## ⚠ Unplanned work absorbed — recorded late, 2026-08-26

★ **This section is the trade the Definition of Done asks for, and it is written after the fact
rather than before.** Eight stories landed that the plan did not contain. The DoD's own rule —
*"if 3 unplanned stories land, the next action is `/sprint-plan`"* — was passed on the third and
not acted on until the eighth. ✅ **`/sprint-plan update` has since run** (2026-08-26): capacity
re-baselined below, and an **intake rule** adopted so the next find is routed rather than absorbed
by default. Sprints 6 and 7 broke the same rule, which is why it was written down.

### Where it came from

Every one of these traces to the same root: **the user played the game.** The first real session
(the one that produced S8-10) surfaced defects that a headless suite structurally cannot see, and
each fix exposed the next. That is the sprint working as intended — ⚠ but the work was absorbed
silently, and the sprint file said something untrue for six merges.

| ID | Story | Owner | Est. | Merge | What it was |
|----|-------|-------|-----:|-------|-------------|
| ✅ **S8-10** | Playtest fixes from the first real session | gameplay-programmer | 0.5 | `69a6447` | Cover floated half a tile (the S6-29 structures defect again); the action menu showed inapplicable verbs; rows printed redundant per-verb key hints |
| ✅ **S8-11** | CR-4 propagation | producer | 0.25 | `4dbc76c` | `/propagate-design-change` for S8-10's structural-vs-situational rule. **0 of 18 ADRs, 0 of 24 TRs affected.** ★ The pass ran *backwards* — the decision had moved in the UX spec and the code, and the GDD was the laggard |
| ✅ **S8-12** | The confirm key, and a Build button wired to nothing | ui-programmer | 0.5 | `6ae29d3` | Keyboard could not choose a verb **at all** — the menu and the board fought over `ui_accept`. Tearing down a focused row left the board deaf. ⛔ And `build_type_chosen` was emitted into a void: **the only path a player can take was dead** while the suite stayed green, because the tests called the method directly. Third dead hook found this way |
| ✅ **S8-13** | Build belongs to a Builder, and the Builder is spent | gameplay-programmer | 1.5 | `5b28d99` | ★★ **User decision.** Build stops being a player-level command (CR-5) and becomes a verb of a selected Builder unit, which is **consumed** by what it raises. HQ makes only Builders; the Barracks becomes the sole source of fighting units. The opening is now fixed: Builder → Barracks → army |
| ✅ **S8-14** | The Builder gets a body — and the art guard gets teeth | technical-artist | 1.0 | `6b5733e` | ASSET-012. ⚠ **The guard was the real bug**: both art-coverage tests carried a hand-transcribed list of the nine types, so the Builder outran the art and the suite stayed green. Both now enumerate `UnitTypes.ALL` / `StructureTypes.ALL` |
| ✅ **S8-15** | A shorter, bulkier Builder | technical-artist | 0.5 | `cc3b81a` | User feedback on the shipped look. ★ **The lever is crouch, not scale** — every wording that shrinks the legs makes SDXL delete them |
| ✅ **S8-16** | A cargo cradle you can actually see | technical-artist | 0.5 | `f168832` | User asked for the cradle to read. Two further generation rounds failed **structurally** — prompt weight is finite — so it is authored geometry composited on the approved master, the same call ASSET-006/007 made for terrain |
| ✅ **S8-17** | An opponent that actually plays | ai-programmer | 1.0 | `31a4cd6` | ⛔⛔ **The AI was demolishing everything it built.** Produce a Builder → spend it on a Barracks → cancel the Barracks for the refund → repeat, every turn. It ended matches owning nothing but its HQ with 6,000+ Credits banked, **and the player was facing an empty board** |
| ✅ **S8-23** | AP per turn → 20 | game-designer | 0.25 | *(pending)* | ★ **User decision, deliberately against the config's own advice.** A Trooper costs 4 AP to move+attack, so 20 activates **5** units where 30 activated 7 — and population caps at 10, so **~half a full army idles each turn**. ⛔ That is the problem the ×3 rescale fixed. Taken as an experiment in tempo pressure: whether scarcity reads as constraint or as being denied your turn is **exactly what a play session can answer and no script can.** ⚠ **Invalidates every S7-09…S7-17 balance number** |
| ✅ **S8-22** | The crate comes off | technical-artist | 0.5 | *(pending)* | ⛔ **Four rounds, abandoned — user's call.** S8-21 found the cause: the hull is **not in the projection it looks like**, its top-left edge measuring **−0.179** against a true dimetric **−0.500**. Every drawn cradle was a perfect rhombus, so it sat on the machine in a different projection. ★ The hunched silhouette already read as "carrier" without it. ✅ Sprite **157 → 145 px**, restoring all of S8-15's "shorter"; tool deleted |
| ✅ **S8-21** | Match the machine's perspective, not the textbook's | technical-artist | 0.5 | `670c871` | The measured-projection fix. ★ **Superseded by S8-22 but the finding stands** and is recorded in `generation-prompts.md`: a generated render is not on your grid |
| ✅ **S8-20** | The crate stops looking tacked on | technical-artist | 0.5 | *(pending)* | User feedback on the approved look. ⚠ **By the intake rule this is a NO — it does not block the measurement and should have gone to `post-gate-backlog.md`.** Admitted on the user's direct request, and recorded as such rather than quietly reclassified. ★ Cost nothing in height: **157 → 154 px** |
| ✅ **S8-19** | A Builder you can tell is yours | technical-artist | 0.5 | `7b4adca` | ⛔ Accent coverage **22.8% vs a 30% floor** — and `accent_coverage_test.gd` kept a hand-written archetype list the Builder was not in, so the gate written to catch exactly this never looked. ★ **Blocks the measurement** — S5-03 observer Q1 is *"can they say which units are theirs"* |
| ✅ **S8-18** | The sprint file tells the truth | producer | 0.25 | `b9de7e8` | This section, and the `/sprint-plan update` that re-baselined it. The plan recorded none of S8-10…S8-17 for six merges, so for most of the sprint it described a sprint that was not happening |

**Absorbed: 8.25 days** (5.75 + S8-18 0.25 + S8-19 0.5 + S8-20 0.5 + S8-21 0.5 + S8-22 0.5). Planned was 4.75 against ~8 available; actual is
**~13.0 against ~8**. ★ The critical path did not slip because of it — S8-01 is gated on the
user, not on capacity — but the sprint is over its box and the plan never said so.

### ★★ What S8-17 says about the test suite

Three independent faults combined, and **no unit test could see any of them**:

1. The anti-oscillation gate keyed on `economy_investments`, the economy-*cadence* counter.
   S6-09 correctly stopped BuildActions counting toward that cadence, which **silently disabled
   the gate**. Two different questions — *"how much cadence have I spent?"* and *"did I just build
   something?"* — shared one variable, so a correct change to one broke the other.
2. `_cancel_build_value` returned **raw Credits** while every verb it competes with is scored in
   AP-equivalent, so a 300-Credit refund outscored any real play by ~100×.
   ⚠ **The unit tests asserted the implementation, so code and tests agreed with each other while
   both contradicted the GDD** — a defect a test written from the code cannot catch by construction.
3. Even correctly scaled, cancel still won on turns with no other candidate. The GDD's *"rarely
   clears PASS_THRESHOLD against a concrete positive play"* quietly assumes a positive play exists.

⚠ **Why it surfaced only now:** faults 1 and 2 were latent for months. S8-13 collapsed the AI's
option set, so on alternate turns cancel became its only move.

★ **The new gate asserts outcomes, not scores.**
`tests/integration/ai-opponent/ai_plays_a_real_opening_test.gd` drives six real turns and requires
the AI to still own a structure at the *end* of a turn, field an army, and spend rather than hoard.
Every prior AI test scored one candidate or drove one turn — **which is exactly why a whole match
of doing nothing sailed through 1,300 green tests.**

### ⛔ What this changes about the pending verdict

**S8-01 must be re-run on the current build, not on the one already played.** The board the user
played is not the board that exists now: Build works differently (S8-13), the AI actually plays
(S8-17), and the keyboard path to a command was dead at the time (S8-12).
★ **Analysis D is affected most** — Build is the economic action whose *feel* the question is
about, and it now costs a whole unit rather than a HUD click. The question is unchanged and still
the sprint's centre; **the answer would simply not have been about this game.**

## Capacity

★ **Re-baselined 2026-08-26** via `/sprint-plan update`, after eight unplanned stories landed.
**Nothing is cut and the sprint goal is unchanged** — the overage is accepted as-is (user's call).

- Total days: 10 · Buffer (20%): 2 · **Available: ~8**
- **Planned: 4.75** (must 2.75 + should 2.0). ★ Deliberately light: **the critical path is
  gated on one hour of the user's time**, and loading the sprint with agent work is how the
  validation half rolled over six times before.
- **Unplanned absorbed: 8.25** (S8-10…S8-23, see the section above). ★ **S8-19 is the intake rule's first live application** — it was admitted because it blocks the measurement, not because it was next
- ⚠ **Actual: ~13.0 against ~8. About 5 days over the box, and the buffer is spent.**
  ⚠ **S8-20 is the first item the intake rule said NO to that was admitted anyway.** Recorded as an
  exception on the user's direct request — ★ **the rule's value is that this is now visible instead
  of invisible**, which is exactly what it was adopted for.

### ★★ Why over-box is the right answer here rather than a cut

**Capacity was never the binding constraint.** S8-01 is gated on **one hour of the user's time**,
not on days available — so the critical path could not have gone faster under a lighter plan, and
did not go slower under a heavier one. Cutting scope now would buy back a resource nothing is
waiting on.

⚠ **Note what that admits: the day estimates do not bind anything in this project.** They are a
record of effort spent, not a budget anyone enforced. Three sprints running have exceeded them
without the excess being noticed at the time. ★ **Treat them as telemetry, not as a gate** — and
do not quote "available days" as though it constrains a decision.

⛔ **What the overage DID cost is real, and it is not capacity.** The deliberately-light plan was
the *stated mitigation* for a play session that had already rolled six times. It was abandoned
without anyone deciding to abandon it — and **the session has now rolled a seventh.** The lost
thing was the mitigation, not the days.

## ★★ Intake rule while the verdict is pending — decided 2026-08-26

**The question to ask of anything found from here on: does it stop the play session from measuring
what it is meant to measure?**

| | Then | This sprint's eight, sorted |
|---|---|---|
| **Yes — it blocks the measurement** | **Fix it now**, and record it as unplanned above | **S8-12** — the keyboard could not choose a verb *at all*, and the Build picker was wired to nothing · **S8-17** — the AI was demolishing everything it built, so the player faced an empty board · **S8-10** — found mid-session · ★ **S8-19** — the Builder's ownership was below the readability floor, and **S5-03 observer Q1 asks precisely whether a viewer can tell whose units are whose** |
| **No** | ⇒ **`post-gate-backlog.md`**, unscheduled, with enough context to be picked up cold | **S8-13** — a core economy change · **S8-14/15/16** — art · **S8-11** — propagation · **S8-18** — bookkeeping · ⚠ **S8-20/21/22** — art polish, admitted anyway on direct request. ★ **Three rounds on one crate that was then deleted.** The rule said no at the start; it would have saved 1.5 days and reached the same end state |

★ **This is Sprint 5's retro rule with one exception carved out, not a new rule.** The routing
mechanism and its destination have existed since 2026-08-21. ⛔ **Nothing was routed to it this
sprint — because nobody asked the question**, not because anyone decided against it.

⚠ **The strict version was considered and rejected.** Routing *everything* would have left the AI
demolishing its own buildings **during the session that decides the project**, and left the
keyboard path dead under a question about how the game feels to play. A measurement instrument
that is broken is not a scope question.

### ⚠ Applied honestly, five of the eight should have gone to the backlog

Including **S8-13, the largest single item in the sprint.** ★ **It was the user's call and is not
being reversed** — the Build-by-Builder rework is a better game and it stays. The point is
narrower and worth keeping: **the call was never framed as a routing decision.** It was framed as
"should Build work this way", which has an obvious answer, instead of "should this happen *now*,
before the premise it changes has been tested" — which does not.

★★ **That is the whole finding of this re-plan.** 6.0 unplanned days entered a sprint that had
budgeted 4.75 in total, and **no individual decision along the way was wrong.**

## ★ Carried and explicitly NOT in this sprint

| Item | Why not |
|---|---|
| **Wave 2 content** (unit classes, pilots, damage types, abilities) | ★★ Designed and waiting, and it must stay waiting. Building on a premise no human has tested is exactly what the re-verdict exists to prevent |
| **Any faction content** | Same reason, plus CR-11's dependency on wave 2 |
| **First-move compensation** | ✅ Accepted 2026-08-25 (S7-18) with revisit triggers in `post-gate-backlog.md` §7 |
| **Native vs Proton** | Needs a Deck; no Deck available |

## Risks

| Risk | P | Impact | Mitigation |
|---|---|---|---|
| ⛔ **The session does not happen** — a seventh roll-over | **High** | **High** | ★ The single mitigation that has not been tried: **make it one hour, one file, one sitting, no protocol to read.** That is S8-00's entire job. Every previous attempt asked the user to run a structured multi-game protocol |
| **No naive observer is available** | Medium | Medium | Part 2 (Analyses A/C/D) does **not** need one and unblocks the verdict on its own. Run it alone and record part 1 as still-owed rather than blocking on it |
| **Analysis D comes back negative** | ★ Medium | **Very high** | It would invalidate the Sprint 4 pivot. ⚠ That is the *point* — better found now than after wave 2 is built on it. A PIVOT verdict is a legitimate outcome and the KILL clause is still not engaged |
| **The verdict is PROCEED but the gate says CONCERNS** | Medium | Low | Expected and fine. The gate names blockers; they become Sprint 9 |
| ⚠ **The build moved under the pending session** — S8-12/13/17 changed the keyboard path, what Build *is*, and whether the AI plays at all | ✅ **Occurred** | Medium | ★ **S8-01 answers must come from the current binary.** Rebuild before playing. The six questions are unchanged and Analysis D is still the sprint's centre — but Build now costs a whole unit rather than a HUD click, so an answer given on the old build would not have been about this game |
| ⚠ **Unplanned work displaces the light-plan mitigation** | ✅ **Occurred** — 9 stories, 6.0 days | Medium | ✅ **Settled 2026-08-26**: capacity re-baselined, overage accepted, **intake rule** adopted (above). ★ The work was *not* discretionary — every story traces to the user playing, which is this sprint's own critical path doing its job. ⛔ **But the mitigation it displaced is still displaced** — the session has rolled a seventh time |

## Definition of Done

- [ ] S5-03's three observer questions have recorded answers
- [ ] S5-04's Analyses A, C and D have recorded answers
- [ ] `REPORT.md` carries a fresh verdict section with all five §10 criteria assessed
- [ ] `/gate-check pre-production` run, verdict recorded, blockers named
- [ ] `production/stage.txt` updated **if** the gate passes
- [ ] Full suite green, slice boots clean, exported binary boots clean
- [x] ◐ No unplanned work absorbed without a recorded trade — ★ **the rule Sprints 6 and 7 both
      broke. Mechanically: if 3 unplanned stories land, the next action is `/sprint-plan`.**
      ⚠ **BROKEN, then recorded late, then settled.** Eight stories landed (S8-10…S8-17); the
      threshold was passed on the third and the trade written at the eighth (S8-18).
      ✅ **`/sprint-plan update` run 2026-08-26** — capacity re-baselined, overage accepted, and
      an **intake rule** adopted so the next find is routed rather than absorbed by default.
      ★ Third sprint running that broke this; **the first that ended with a rule instead of an
      apology.**
- [ ] ⛔ **S8-01 re-run against the CURRENT build** — the game the user played is not the game that
      exists now (S8-12 keyboard, S8-13 Build-by-Builder, S8-17 an AI that plays)
