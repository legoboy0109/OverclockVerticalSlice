# Gate Check: Pre-Production → Production

**Date**: 2026-08-24
**Checked by**: `/gate-check pre-production`
**Review mode**: `lean`
**Previous run**: `gate-pre-production-production-2026-07-28.md` — verdict **CONCERNS**
**Verdict**: ⛔ **FAIL** *(upgraded from CONCERNS)*

> **Why this is more severe than last time, not less.** On 2026-07-28 the gate returned
> CONCERNS because the vertical-slice playtests were simply *absent* — an evidence gap. It is
> now FAIL because the evidence arrived and it is **negative**: `production/vertical-slice/REPORT.md`
> records a **PIVOT** verdict on measured grounds. A missing measurement is a concern; a
> measurement showing the core loop has no reliable resolution is a blocker.

---

## Required Artifacts: 12 / 13 present

| # | Artifact | Status |
|---|---|---|
| 1 | Vertical slice REPORT.md | ✅ `production/vertical-slice/REPORT.md` — **verdict PIVOT** (was the missing artifact last run) |
| 2 | First sprint plan | ✅ `production/sprints/sprint-1..5.md` |
| 3 | Art bible complete (9 sections) + AD sign-off | ✅ 97KB, AD APPROVE recorded |
| 4 | Entity inventory | ✅ `design/assets/entity-inventory.md` |
| 5 | All MVP-tier GDDs complete | ✅ 10 of 10 Approved (systems-index) |
| 6 | Master architecture document | ✅ `docs/architecture/architecture.md` (35KB) |
| 7 | ≥3 Foundation ADRs | ✅ 18 ADRs |
| 8 | **All Foundation + Core ADRs `Accepted`** | ✅ **18 / 18 Accepted** — verified individually, none `Proposed` |
| 9 | Control manifest | ✅ `docs/architecture/control-manifest.md` (79KB) |
| 10 | Epics with Foundation + Core layers | ✅ 13 epics in `production/epics/` |
| 11 | VS build exists and is playable | ✅ Boots clean, full loop confirmed windowed |
| 12 | UX specs (main menu, HUD, pause) + `/ux-review` APPROVED | ✅ `design/ux/{main-menu,hud,pause,interaction-patterns}.md` |
| 13 | **VS playtested, ≥1 documented session** | ⛔ **NOT MET.** Two protocols authored; the swing-back *session* file (2026-08-19) is open but **entirely empty**; the iso-legibility session has **never been run** (3 sprints). What exists is an **AI-vs-AI simulation appendix** which its own header states *"is NOT the swing-back playtest and does not close S5-04"* |

> **Note on artifact naming, checked not assumed:** the gate expects
> `docs/architecture/requirements-traceability.md` and `design/ux/hud-design.md`. This project uses
> `docs/architecture/traceability-index.md` (+ `tr-registry.yaml`) and `design/ux/hud.md`. Both are
> present under the project's own names. **Not a gap.**

---

## Quality Checks: 8 / 12 passing, 1 failing, 3 unverifiable

| Check | Result |
|---|---|
| Tests passing | ✅ **984 / 984**, 89 suites, 0 failures, 0 flaky, 0 orphans — run 2026-08-24 |
| Sprint plan references real story file paths | ✅ `production/epics/**/story-0NN-*.md` |
| Architecture has no unresolved Foundation/Core open questions | ✅ |
| ADRs stamped with engine version / dependency sections | ✅ (per `architecture-review-2026-08-05.md`) |
| ADR circular dependency check | ✅ No cycles |
| UX specs cover MVP GDD UI Requirements | ✅ |
| Accessibility tier addressed in key screen specs | ✅ Standard tier; **corrected** 2026-08-20 after S5-08 found three docs asserting a non-hue silhouette backup that was never built |
| Interaction pattern library current | ✅ |
| **Core loop fun is validated** | ⛔ **FAIL** — see Blockers |
| Core fantasy independently described by a playtester | ❓ **MANUAL CHECK NEEDED** — no session has been run with an observer |
| Game communicates what to do within 2 minutes | ❓ **MANUAL CHECK NEEDED** — this is precisely what S5-03 exists to judge |
| Core mechanic feels good to interact with | ❓ **MANUAL CHECK NEEDED** — Analyses A / C / D of the swing-back protocol are untouched |

### Vertical Slice Validation (the gate's hard rule)

> Gate rule: *"Slice was built AND any validation item is NO → verdict is automatically FAIL."*

| Item | Result |
|---|---|
| A human has played the core loop without developer guidance | ✅ Yes — confirmed in the Sprint 3 smoke close-out and the 2026-08-19 session |
| The game communicates what to do within the first 2 minutes | ❓ Unverified |
| **No critical "fun blocker" bugs exist** | ⛔ **NO** — the AI never attacks an HQ (0 HQ damage in 4,182 + 1,260 turn-rows). **The AI has no path to victory; the human can win but cannot lose.** Capped matches resolve to an exact 40/40 tie broken by **seat**, ~95–100% against the human's seat |
| The core mechanic feels good | ❓ Unverified |

**The slice was built and one validation item is NO. The gate's own rule makes this FAIL.**

---

## Blockers

1. ⛔ **The core loop has no reliable resolution — "fun validated" cannot be asserted.**
   The AI never attacks an HQ, so no match becomes *decided on play*. A +3 Trooper starting
   advantage converted to a win in **0 of 5** attempts. Root cause is measured and is **not** the
   AI's siege term (which exists, fires, and was proven not to be the bottleneck): **Credits are
   unbounded** (peak 5,724, still climbing at turn 200), so economy actions outscore manoeuvring by
   **12–20×** and are always affordable, consuming the AP budget before any unit marches.
   *Resolution:* bound the economy per `production/vertical-slice/PIVOT-NOTE.md` §3, then re-run
   the AI-vs-AI regression gate.

2. ⛔ **Neither required human playtest has been run — three sprints running.**
   S5-03 (iso-legibility, a Pillar-3 **hard** gate) and S5-04 (swing-back Analyses A/C/D, the
   economy pivot's core hypothesis) are the only source of evidence for the felt half of the
   PROCEED criteria, and no simulation can substitute for either.
   *Resolution:* run both **after** blocker 1 is fixed — playing the current build means judging a
   game whose central failure is already known and already scheduled for repair.

3. ⚠ **No victory/defeat presentation exists for any win path.**
   `game-hud.md` CR-9 / AC-17 / AC-22 are all unimplemented; a one-line status message is the
   stopgap. Latent while matches never ended; player-facing now that they do. Not a gate blocker
   on its own, but it will distort any legibility session run before it is fixed.

---

## Recommendations

- **Do not advance.** Stage stays **Pre-Production**. The PIVOT verdict spawns focused
  economy/tempo work; this gate is re-run after it, not before.
- Treat the **AI-vs-AI simulation batch as the cheap regression gate** for that work
  (`./redot --headless tools/SimulateMatches.tscn`). Pass condition in `PIVOT-NOTE.md` §3.
- **Keep** `VS_MAX_ROUNDS = 30` armed and the `TOTAL_HQ_HP` tiebreak default. Both are correct and
  both are load-bearing for the next measurement.
- Fix blocker 3 alongside the economy work — it is small and it improves the quality of the
  playtest sessions that follow.
- Nothing in this verdict invalidates an ADR. **18 / 18 remain Accepted**; the projected fix is
  data and scoring, not architecture.

---

## Director Panel

**Skipped — artifact-determined**, matching the precedent set by the 2026-07-28 run. The verdict
follows mechanically from the gate's own Vertical Slice rule (slice built + a validation item NO →
FAIL) and from a PIVOT verdict in `REPORT.md`. No director judgement could move it, and the design
question the panel would weigh in on is already answered and recorded.

---

## Chain-of-Verification

5 questions checked — **verdict unchanged (FAIL)**.

1. *Have I accurately separated hard blockers from strong recommendations?* Yes. Blockers 1 and 2
   are gate conditions verbatim; blocker 3 is flagged as **not** independently blocking.
2. *Are there PASS items I was too lenient about?* **[TOOL ACTION]** Re-checked every ADR's Status
   section individually rather than trusting the prior gate's claim — **18/18 genuinely `Accepted`**,
   none `Proposed`. Item 8 stands.
3. *Am I missing blockers the user should know about?* **[TOOL ACTION]** Re-ran the full suite:
   **984/984, 0 failures, 0 orphans** — higher than the 955 last recorded, so no hidden regression
   is masking anything. Test health is genuinely not a blocker.
4. *Is this a deeper design problem, or resolvable?* Resolvable. The failure is a **missing bound
   on an existing resource**, not a broken architecture. The two-budget economy, deterministic
   combat, render stack and faction framework all work.
5. *Minimal path to PASS — the specific three things?*
   (a) bound the economy and prove it with the AI-vs-AI regression gate;
   (b) run S5-03 and S5-04 for real against the repaired build;
   (c) update `REPORT.md` to PROCEED on that evidence and re-run this gate.

---

## Verdict: ⛔ FAIL

`production/stage.txt` remains **Pre-Production** — unchanged, not written.
