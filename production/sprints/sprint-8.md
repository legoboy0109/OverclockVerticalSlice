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
| **S8-00** | **Prepare the session** — a single ready-to-fill file with all six questions, room for notes, and no set-up required from the user | producer | 0.25 | — | The user opens one file, plays, and writes prose. No form-filling, no protocol to read first |
| ⛔ **S8-01** | **The play session** — S5-03 observer + S5-04 Analyses A/C/D | **user** | 1.0 | S8-00 | Six questions answered in the user's own words. Partial is fine and still unblocks the verdict |
| **S8-02** | **Analyse and write up** — turn the notes into findings against the S5-03 and S5-04 reports | qa-lead | 0.5 | S8-01 | Each of the six questions has a recorded answer and a PASS / CONCERN / FAIL |
| **S8-03** | ⛔ **`/vertical-slice` re-verdict** — a fresh PROCEED / PIVOT / KILL against `scope.md` §10 | producer + creative-director | 0.5 | S8-02 | All five criteria assessed with evidence. `REPORT.md` gains a new verdict section; the PIVOT stays as history |
| **S8-04** | ⛔ **`/gate-check pre-production`** | technical-director | 0.5 | S8-03 | PASS / CONCERNS / FAIL with named blockers. ★ A PROCEED here is what advances `production/stage.txt` to Production |

### Should Have — runs while S8-01 is pending

| ID | Task | Owner | Est. | Notes |
|----|------|-------|-----:|-------|
| **S8-05** | **Accent-coverage check in the asset pipeline** | technical-artist | 0.5 | ★ S5-03's own recommendation #2, still open. The Sniper defect shipped and survived a full art sprint **because nothing measured it**, and every wave-2 unit has the same failure mode available. `analyse_legibility.py` already computes the number |
| **S8-06** | **Controller glyphs** — the legend names keyboard keys regardless of active device | ui-programmer | 1.0 | Deck Verified gap 1. The bindings all exist; only the *display* is wrong |
| **S8-07** | **Text legibility at 1280×800** — pick a sensible `ui_scale` default for the floor | ux-designer | 0.5 | Deck Verified gap 2, and the action-menu spec's open advisory. ★ Testable now against the real binary |

### Nice to Have

| ID | Task | Est. | Notes |
|----|------|-----:|-------|
| **S8-08** | Idle power draw — conditional throttle, not `low_processor_usage_mode` outright | 0.5 | ⚠ The glow pulses and motion runs on tweens; sleeping the loop makes both choppy. Wants measuring on device |
| ✅ **S8-09** | Verify Redot/Godot dual-focus parity | 0.25 | **DONE 2026-08-26 — PASS.** `tools/CaptureDualFocus.tscn`, 8/8 checks, deterministic ×3. Closes the ux-review's advisory 4 and GDD OQ-6. ⚠ Opened `action-menu.md` **OQ-7**: hover is close to invisible on its own (~3% lift; `flat` suppresses the hover StyleBox) — a design call, left open. Report: `production/playtests/s8-09-dual-focus-2026-08-26.md` |

## Capacity

- Total days: 10 · Buffer (20%): 2 · **Available: ~8**
- **Committed: 4.75** (must 2.75 + should 2.0). ★ Deliberately light: **the critical path is
  gated on one hour of the user's time**, and loading the sprint with agent work is how the
  validation half rolled over six times before.

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

## Definition of Done

- [ ] S5-03's three observer questions have recorded answers
- [ ] S5-04's Analyses A, C and D have recorded answers
- [ ] `REPORT.md` carries a fresh verdict section with all five §10 criteria assessed
- [ ] `/gate-check pre-production` run, verdict recorded, blockers named
- [ ] `production/stage.txt` updated **if** the gate passes
- [ ] Full suite green, slice boots clean, exported binary boots clean
- [ ] No unplanned work absorbed without a recorded trade — ★ **the rule Sprints 6 and 7 both
      broke. Mechanically: if 3 unplanned stories land, the next action is `/sprint-plan`.**
