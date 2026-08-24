# Vertical Slice — REPORT — OVERCLOCK "One Close Skirmish"

> **Verdict: PIVOT** · **Date**: 2026-08-24 · **Stage**: Pre-Production (unchanged)
> **Scope under test**: `production/vertical-slice/scope.md` (APPROVED 2026-07-27)
> **Story**: S5-05 · **Sprints covered**: 3 (build) → 4 → 5 (validation)

---

## 1. The verdict in one paragraph

The slice **builds**, at representative quality, and does everything §10's KILL clause tests
for — so KILL is off the table and was never close. But it cannot PROCEED, for one structural
reason and one procedural one. **Structurally: the game has no reliable way to resolve.** Under
AI play the opponent never attacks an HQ — zero HQ damage across 4,182 turn-rows and again
across a further 1,260 after a siege drive was added — so no match becomes *decided* on play,
and the round cap resolves games to an exact tie broken by **seat**, not by skill. A +3 starting
material advantage never once converted into a win. **Procedurally: the iso-legibility gate
(S5-03) has not been run**, and PROCEED requires it to pass. This maps precisely onto §10's PIVOT
clause — *"swing-back absent/muted → revisit economy tuning"* — and onto CD amendment A, which
routes a muted swing-back to PIVOT and explicitly never to KILL.

**The single sentence worth carrying forward:** *the economy is unbounded, so building always
outscores fighting, so nobody ever marches on the objective, so no game is ever won.*

---

## 2. Verdict against §10's criteria, line by line

### PROCEED — not met (2 of 5 unmet, 1 unassessable)

| §10 PROCEED criterion | Result | Evidence |
|---|---|---|
| Player completes the full loop **unguided**, cold start → win-check | ✅ **MET** | Windowed manual loop confirmed by the user across the Sprint 3 close-out and the 2026-08-19 session: boot, input, move (all four unit types), attack, produce, build, turn handoff, live HUD. `production/qa/smoke-2026-07-28.md` |
| Loop built within the time box at representative quality | ✅ **MET** | Real art on the board (62 runtime PNGs), glow shader live, four state transforms, ownership decals, dual-budget HUD. Suite green throughout |
| **Iso-legibility PASS** (readable at the shipping camera; silhouettes distinguishable in grayscale; ownership clear by hue) | ⛔ **NOT RUN** — and one clause is *known false* | S5-03 never played (3 sprints). Separately, S5-08 measured that **all 26 Rush/Boom sprite pairs are pixel-identical**, so "silhouettes distinguishable in grayscale" fails *as authored*; the tile ownership decal now carries that read instead |
| **Swing-back PASS** (≥1 close game flips via stabilization; **no decided game reverses**) | ⛔ **UNASSESSABLE, and structurally blocked** | The hard gate is satisfied only *trivially*: no decided game reverses because **no game becomes decided**. See §3 |
| The tempo fantasy is **felt** — a specific moment where allocation decided the turn | ⛔ **UNTESTED** | Analysis A/C/D of the swing-back protocol are entirely human-judgement and the session file is empty. Simulation cannot answer any of them |

### PIVOT — met, on the clause the scope itself names

> §10: *"Swing-back absent/muted, or a decided game DID reverse → revisit economy tuning… **A muted swing-back routes here (PIVOT), never to KILL** (§7.1, CD amendment A)."*

Met. The swing-back is not merely muted — the *mechanism that would produce one* never engages,
and the diagnosis lands squarely on **economy tuning**, which is exactly where §10 routes it.

> ⚠ **The named first lever has already been spent.** §7.1 designates "adding build-outpost" as
> the first PIVOT lever, on the assumption the slice shipped with flat income and no outposts.
> Outposts **shipped** (Base & Production, Sprint 3) and the economy was subsequently split into
> AP + Credits (Sprint 4). The lever that §7.1 held in reserve is now part of the baseline — and
> is, on the measurement, *the thing that broke*. **The replacement first lever is to bound the
> economy** (§4).

### KILL — not met, and not close

| §10 KILL criterion | Result |
|---|---|
| Loop cannot be built at representative quality within the box | ❌ Not met — it was built |
| No emotional high point in any session | ❌ Not assessable, and not claimed — no full session has been played |
| >50% of what was built needs architectural rebuild | ❌ Not met. The projected fix (§4) is **data and scoring**, not architecture: a Credit sink/cap plus AI re-weighting. 18 ADRs remain Accepted; none is invalidated by this verdict |

---

## 3. The finding, in full

Source: `production/playtests/swing-back-simulation-appendix-2026-08-21.md` — 20+21 AI-vs-AI
games driven by the *shipped* `AI.choose_action`, differentiated by a 0–3 Trooper starting
handicap (a self-handicap the protocol explicitly sanctions).

**3.1 — The AI never attacks an HQ.** Zero HQ damage in 4,182 turn-rows. Both HQs finished every
game at 40/40. This is not a missing weight: `hq_siege_value` is **12**, generous against a unit's
produce cost, with an AC-29 regression guard against it being zero.

**3.2 — Adding a siege drive did not fix it.** `siege_value_per_tile_closed = 0.20` was added and
is covered by 7 tests. It **provably fires** in isolation — a unit 4 tiles from the enemy HQ moves
to within 2, and leftover turn AP goes into siege moves. In real matches it changed **nothing**:
0 HQ damage across 1,260 further rows.

**3.3 — The measurement that explains it.** Sweeping the siege weight against a Credit-rich
position, the AI keeps choosing `BUILD` until the weight reaches **2.0–4.0 — 12–20× the ordinary
positional rate of 0.16.** Economy actions do not merely beat manoeuvring; they beat it by an
order of magnitude. And with **Credits unbounded** (peak observed **5,724**, still climbing
linearly at turn 200) they are *always affordable*, so the AP budget is consumed before any unit
marches. Raising the siege weight into that band would make the AI abandon its economy entirely —
trading one degenerate behaviour for another, not a credible opponent.

**3.4 — The chain.** Every other symptom in the appendix hangs off one cause:

> unbounded Credits → economy always wins scoring → no manoeuvre → no HQ damage → no decisive
> win → every game reaches the cap → tiebreak → **exact tie** → decided by **seat**

**3.5 — Two fixes landed during the investigation and are correct, but neither resolves it.**
- `VS_MAX_ROUNDS = 30` armed. Termination went from **0/20 games ending** to **19/19**. Keep it.
- `TiebreakMetric.TOTAL_HQ_HP` implemented and made default (it was always the spec default;
  only `UNIT_COUNT` had shipped, and it counted *every entity*, rewarding pure booming). The boom
  exploit is closed and unit-tested. **Correcting it moved AI-vs-AI outcomes not at all — 7 of 7
  still to player 1 — which is what proved the seat skew was never the metric's fault.**

**3.6 — The human sits on the losing side.** `LOCAL_PLAYER = 0`; capped games go ~95–100% to
player 1. For human play the corrected metric now behaves properly (batter the enemy HQ and you
win a capped game; you cannot be out-built out of it) — but a human game that reaches turn 30 is
still being decided by a rule that never measured play.

**3.7 — What simulation cannot answer, and still owes a human.** Analysis A (does the swing feel
alive), C (does tempo read at a glance) and D (does spending Credits *feel* like a tempo cost —
the economy pivot's core hypothesis) are untouched. So is the whole of S5-03.

---

## 4. What the next slice must prove differently

Full detail in `production/vertical-slice/PIVOT-NOTE.md`. In short:

1. **Bound the economy.** A Credit sink and/or cap, so accumulation cannot outrun every other
   consideration. This is the replacement first lever, and it is the one change the measurement
   actually prescribes.
2. **Then re-measure the siege term** — the existing 0.20 weight is predicted to surface on its
   own once Credits are bounded. If it does, that is the confirmation the diagnosis is right.
3. **Give matches a shorter, more decisive natural arc** so the round cap is a genuine backstop
   rather than the usual result.
4. **Re-run the AI-vs-AI batch** as the cheap regression: the pass condition is *games resolving
   on play, from both seats, with the material-advantaged side winning more often than not.*
5. **Then run S5-03 and S5-04 for real.** They are still owed, and they are still the only source
   of evidence for the felt half.

---

## 5. Velocity log

| Sprint | Window | Planned | Completed | Rate |
|---|---|---|---|---|
| Sprint 1 — Foundation | — | 7 | 7 | 100% |
| Sprint 2 — VS Enablement | — | 8 | 8 | 100% |
| Sprint 3 — VS Build | →2026-07-28 | 26 stories + 7 tasks | 26 stories + 1 bonus / 1 task | 100% build · ~14% sprint-tasks |
| Sprint 4 — VS Validation | 07-29→08-12 | 10 | 4 | **40%** |
| Sprint 5 — VS Validation (cont.) | 08-19→09-02 | 10 | **6** (S5-01/02/06/07-captures/08 + S5-05) | **60%** |

**Test suite across the arc:** 177 (Core) → 826 (S3 close) → 860 (S4 close) → **984** (S5, verified 2026-08-24).

**★ The pattern that dominates this project's velocity, three sprints running:** everything an
agent can do headlessly gets done; everything needing a human at a display does not. S5-03 and
S5-04 have now rolled over **three** times. This verdict deliberately unblocks the rest of the
project from that queue rather than waiting a fourth.

**★ The second pattern, and the more encouraging one:** every significant defect in this report
was found by *building a tool that could actually look at the game* — the simulation harness and
the windowed capture harness. Both were built in Sprint 5, both found real, months-old defects
that a green headless suite of 900+ tests had never once flagged. That is the practice worth
keeping.

---

## 6. What worked at slice quality (do not re-litigate these)

- **The two-budget economy is mechanically sound and fully wired** — AP flat-with-carry, Credits
  banked, dual-cost both-or-neither, AP surcharge on economic actions, AI scoring via
  `CREDIT_TO_AP_RATE`. What is wrong is that Credits are *unbounded*, not that the split was wrong.
- **The render stack** — sprite feed, glow shader with per-instance hue, four state transforms,
  the death echo, tile ownership decals. Four render layers, ADR-0013 amended and consistent.
- **Deterministic combat (Pillar 2)** — untouched by every change above, exactly as intended.
- **The faction framework** — Approved, built, and inert at Neutral. It absorbed the entire
  AP→Credits pivot without a schema change.
- **The test discipline** — **984 tests, 89 suites, 0 failures, 0 orphans** — verified green at the time of this verdict.

---

## 7. Sign-off

| Role | Verdict | Date |
|---|---|---|
| Producer | **PIVOT** — evidence is sufficient and the KILL clause is not engaged | 2026-08-24 |
| Creative Director | **PIVOT** — routes per §10 + CD amendment A (muted swing-back → PIVOT, never KILL) | 2026-08-24 |
| User (final call) | **PIVOT** — decided 2026-08-24 | 2026-08-24 |

> **Stage remains Pre-Production.** A PIVOT verdict does not advance the gate; it spawns the
> focused follow-up recorded in `PIVOT-NOTE.md`, after which the slice is re-validated and
> `/gate-check pre-production` is re-run.
