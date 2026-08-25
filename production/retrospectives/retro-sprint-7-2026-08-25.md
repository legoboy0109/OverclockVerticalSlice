## Retrospective: Sprint 7 — Harden What Exists
Period: 2026-08-25 (single working day)
Generated: 2026-08-25

> **The sprint set out to tidy up and instead found that the game could not be built, that three
> separate measurement instruments had been lying, and that the project's biggest open design
> question did not exist.** Every one of those was found by *building something that could look at
> the thing*, and none by reading code.

### Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Stories | 4 named (S7-05…S7-08) | **18** (S7-01…S7-18) | +14 |
| Completion rate | — | **100%** | — |
| Committed estimate | ~2.5 days | 10.25 days of story estimate | +7.75 |
| Commits (first-parent) | — | 15 merges / 36 commits | — |
| Files changed | — | 105 (+45,472 / −1,157) | — |
| Test suite | 1236 | **1262** | +26 |
| Playtest/diagnostic reports | — | 10 | — |
| Raw evidence batches | — | 13 | — |
| ⛔ **Ship-blocking defects found** | 0 expected | **2** | — |
| ⛔ **Broken measurements found** | 0 expected | **3** | — |

### Velocity Trend

| Sprint | Planned | Completed | Rate |
|--------|---------|-----------|------|
| Sprint 1 (Foundation) | 7 | 7 | 100% |
| Sprint 2 (VS Enablement) | 8 | 8 | 100% |
| Sprint 3 (VS Build) | 26 stories + 7 tasks | 26 + 1 bonus | 100% build |
| Sprint 4 (VS Validation) | 10 | 4 | **40%** |
| Sprint 5 (Renderer) | 10 | 6 | **60%** |
| Sprint 6 (Prove the fix) | 10 | 10 planned + 28 unplanned | 100% plan · 380% scope |
| **Sprint 7 (Harden)** | **4** | **18** | **100% plan · 450% scope** |

**Trend**: the plan-versus-scope gap widened again, but for a different reason than Sprint 6's.
Sprint 6 overran because work kept arriving. **Sprint 7 overran because the first task uncovered a
defect, whose fix uncovered the next.** Every unplanned item was a direct child of a planned one.
★ That is a chain, not drift — but it is still 4.5× and it was still not re-planned mid-flight.

---

### What Went Well

**1. ★★ "Build something that can look at it" found everything.** Not one significant finding this
sprint came from reading code. Each came from producing an artefact and inspecting it:

| Instrument | What it exposed |
|---|---|
| An export preset | Two ship-blocking defects (`Research` under `tests/`, an autoload⇄Resource parse cycle) |
| A play-strength dial | The one-unit cliff was a measurement artifact |
| `--swap-hqs` / `--start-player` | The seat bias was board position, not seat or turn order |
| `SIM_COVER_USE` telemetry | The cover experiment had silently no-opped |
| A real binary | Confirmed the export fixes in the artefact a player runs |

★ This is the **third sprint running** where tooling that can observe the game found what a green
suite could not. It should stop being framed as a happy accident and start being the default first
move.

**2. ★★ Negative results were treated as results.** Five levers were measured and rejected:
tougher units, more lethal units, cover-as-a-balance-fix, unit counterattacks, and first-turn AP.
Each is now documented *with its measurement* so it is not re-tried. The `first_turn_ap_bonus` knob
ships at 0 with the sweep recorded beside it — deliberately kept rather than deleted.

**3. The verification discipline held under pressure.** Every guard written this sprint was
verified by **re-introducing the defect**, not by watching it pass. That caught a guard which could
not fail, and a cover experiment that did nothing. Both would have shipped as false assurance.

**4. Structural guards over behavioural ones, where the bug is structural.** `export_safety_test.gd`
tests file layout, which no amount of running the game can observe. The right shape for the problem.

---

### What Went Badly

**1. ⛔⛔ Three separate measurements were broken, and two of them produced confident published
conclusions before anyone checked.**

| Instrument | Failure | Consequence |
|---|---|---|
| AI-vs-AI harness | Both seats run one identical policy | "No recoverable middle" was structurally unprovable — became the top design question for two days |
| Cover experiment | `PackedByteArray` is a value type; the mutation hit a local copy | A whole sweep returned byte-identical to its own baseline |
| `--swap-hqs` attribution | Bonus units placed from map constants, not the owned HQ | Spawned beside the *enemy* base; produced a clean, confident, wrong attribution |

★ **The tell was the same every time: results that were *too* clean.** Byte-identical rows, a
perfect 14/0, an unchanging number across a 6× parameter sweep. **Suspicious tidiness is the
signal.**

**2. ⛔ A stale comment cost a whole mis-scoped story.** `VS_MAX_ROUNDS` claimed `UNIT_COUNT` was
"the only implemented metric". It had been superseded four days earlier, and the enum said so.
S7-16 recommended "change the tiebreak metric" against a metric that was already correct, and
S7-17 was scoped to implement a no-op. ⇒ **A comment describing another file's behaviour is a
claim with an expiry date.**

**3. ⛔ The direction of a finding flipped twice as biases were removed.** The first-move effect
read as a *first*-mover advantage with movement bias present, again with placement bias present,
and finally as a *second*-mover advantage on clean data. **Two published recommendations had to be
retracted.** ⇒ **Do not attribute a direction from a partially-cleaned measurement.** Wait for the
control to read clean — here, until the seat matrix read 7/7.

**4. The same trap appeared three times: compensating with a non-binding resource.** Money was not
the constraint (S7-10), cover could not register because the AI cannot use it (S7-11), AP is not
scarce (S7-16). Each looked like an obvious lever; each was inert.

**5. Independence was not achieved, twice.** S7-07 existed *because* the previous action-menu
review was a self-audit by the spec's author. The re-review was too.

**6. Not re-planned mid-flight — again.** Sprint 6's retro action #1 was *"re-plan, don't silently
extend"*. Sprint 7's plan was written **after** four stories had shipped, and then fourteen more
arrived without another re-plan. The action item was followed once and then not again.

---

### Action Items

| # | Action | Owner | Trigger |
|---|---|---|---|
| **1** | ★★ **Distrust clean results.** A byte-identical batch, a perfect N/0, or a flat line across a parameter sweep is a signal to verify the instrument *before* reading the result. Verify by changing the input and confirming the output moves | qa-lead | Any measurement |
| **2** | ★★ **Do not attribute a direction until the control is clean.** State the residual, not its cause, while a known bias remains | qa-lead | Any bias investigation |
| **3** | ★ **Before compensating with a resource, check the resource is binding.** Measure spend-vs-available first | systems-designer | Any balance compensation |
| **4** | ★ **A comment about another file's behaviour needs a source reference or it should not be written.** Prefer pointing at the authority over restating it | lead-programmer | Code review |
| **5** | **Build the observer first.** For any question about behaviour, the first move is an instrument that can watch it — not a code read | technical-director | Any investigation |
| **6** | ⛔ **Re-plan rule, second attempt.** Sprint 6 and 7 both broke it. Make it mechanical: **if 3 unplanned stories land, the next action is `/sprint-plan`, not a 4th story** | producer | Every sprint |
| **7** | **Independence needs a different author, not a different day.** Either a separate session with no authoring context, or a human. A same-author re-review is worth less than its cost implies | ux-designer | Any spec review |

### Carried Process Debt

- **S5-03 and S5-04's human halves have now rolled SIX sprints.** ★ Sprint 6 proved most of both
  were scriptable and closed those parts. What remains is genuinely irreducible: a ~20-minute
  observer session and three feel questions. **Nothing an agent does will move them.**
- **The Sprint 4 retro was never run.** Still true.

### ⛔ What this sprint did NOT settle

- **Whether any of it feels like anything.** S5-04's Analysis D — *does spending Credits feel like
  a tempo cost?* — is the two-budget pivot's founding premise and remains untested by a human.
- **Whether the game runs on the hardware it now targets.** A Deck floor was chosen; no Deck has
  run the build; four Verified gaps are recorded and unaddressed.
- **Whether the slice is fun.** Every measurement this sprint was about correctness or fairness.
