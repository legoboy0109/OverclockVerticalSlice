# Sprint 6 — 2026-08-25 to 2026-09-08 (Prove the PIVOT fix)

## Sprint Goal

**Make matches resolve on play.** Implement the economy rework — upkeep, research-driven
income, per-structure maximums — and prove it with the AI-vs-AI simulation batch that
diagnosed the failure in the first place.

> ★ **This sprint is deliberately NOT about factions.** The faction corpus is written
> (16 documents, 6 factions) and none of it can be trusted until the economy underneath it
> resolves a match. Everything here validates the foundation those factions stand on.

## Context — how we got here

`production/vertical-slice/REPORT.md` returned **PIVOT** on 2026-08-24. Root cause, measured:

> *The economy is unbounded, so building always outscores fighting, so nobody ever marches
> on the objective, so no game is ever won.*

Credits peaked at **5,724** and were still climbing at turn 200. Zero HQ damage across 4,182
turn-rows, and zero again across 1,260 more after a siege drive was added and proven to fire.
`production/vertical-slice/PIVOT-NOTE.md` names the replacement lever: **bound the economy.**

## ⛔ The gate this sprint exists to pass

```
./redot --headless tools/SimulateMatches.tscn
```

**Pass condition (from PIVOT-NOTE §3):**
- Games resolve on **play** (HQ destruction), not on the round cap
- Resolution is **not seat-determined** — outcomes appear from both seats
- The **material-advantaged side wins more often than not** (today: +3 Troopers wins 0 of 5)
- **Non-zero HQ damage** appears in the turn-rows at all (today: literally zero)

★ **If this batch does not flip, nothing else in this sprint matters.** Run it early and often,
not once at the end.

### ✅ GATE PASSED — 2026-08-24, batch 5 (commit `2626f6d`, merged `ae120bc`)

| Pass condition | Baseline | Batch 5 | |
|---|---|---|---|
| Resolve on **play**, not the round cap | 0/20 | **18/21** end by HQ destruction, mean 25 turns | ✅ |
| **Non-zero HQ damage** at all | zero across 4,182 turn-rows | lowest HQ seen **1 of 40**; 608 rows carry damage | ✅ |
| Not **seat-determined** | 95–100% one seat | kills split **P0 9 / P1 9** | ✅ |
| Material advantage **converts** | +3 Troopers won 0 of 5 | **18/18** handicapped games | ✅ |
| (economy bound) peak banked Credits | 5,724 and still climbing at turn 200 | **9,550**, flat — target was <15,000 | ✅ |

**The 3 games that go the distance are the +0 mirror.** A deterministic AI on a symmetric
board *should* tiebreak, so this is correct behaviour rather than residual stall — and the
harness gives that cell **n=1, not n=3**: `variant` perturbs bonus-unit placement, and at +0
handicap there are no bonus units. All three are byte-identical. Worth fixing in the harness
before that cell is used to conclude anything.

**What actually did it.** Four levers were tried. Three of them — bounding the economy,
implementing `CREDIT_TO_AP_RATE`, and valuing production capacity — each found and fixed a
genuine defect and each moved resolution **not at all**. The two that moved it were about
incentives: production cooldowns (slower reinforcement) and, decisively, **making the objective
outscore trading**. `_combat_value` scaled an HQ hit by `hp_removed / max_hp`, so a 5-damage
chip scored 0.75 against 3.00 for killing a Trooper; units correctly broke off a reachable
objective to fight. `hq_siege_value` 12 → 60 (break-even 48). See `.agent/notes.md` for the
full post-mortem and the method lesson.

> ⚠️ **One result to read sceptically:** 18/18 handicap conversion is a *total* correlation
> between material advantage and victory. The gate asked for "more often than not" and got
> determinism. That is the right direction, but it suggests the slice currently has no comeback
> mechanism — worth a look during balance work, not now.


## ★★ Read before writing any code — two corrections that invalidate old measurements

| # | What | Why it blocks measurement |
|---|---|---|
| **1** | **`CREDIT_TO_AP_RATE` must ship at 0.01, not 1.0** (`ai-opponent.md`, cross-review B-5) | The ×100 Credit rescale broke its derived 1:1 anchor. At 1.0 the AI values building and killing **~100× a march** — the exact PIVOT failure mechanism amplified. **A batch run at 1.0 measures an agent that cannot manoeuvre and would make the fix look like it failed.** |
| **2** | **`UPKEEP_DIVISOR` needs `UPKEEP_GRANULARITY`** (`unit-upkeep.md`) | `ceil(produce_cost/3)` was doing heavy rounding on small numbers. At ×100 it drifts low, the roster mean falls 200 → ~150, and the sustainable army rises ~9 → ~12 against a cap of 10 — silently breaking the cap/upkeep relationship. |

> ★ Both are conversion/rounding constants that a "purely proportional" rescale does **not** carry
> safely. Neither was findable by grepping for stale names. Audit this class of constant first.

## Capacity

- Total days: 10 (2-week sprint) · Buffer (20%): 2 days · **Available: ~8 days**
- **Committed: 7.5 days** (must 5.5 + should 2.0), per the standing rule that must+should must not
  exceed available days. Nice-to-haves ride the buffer.

## Tasks

### Must Have — the critical path

| ID | Task | Owner | Est. | Deps | Acceptance |
|----|------|-------|-----:|------|------------|
| **S6-01** | **Economy re-base: delete outpost income, add research tiers** — `credit_income = BASE_INCOME(1000) + Σ tier(+500)`; three sequential economy techs at 1,000/2,000/3,500; remove `OUTPOST_BONUS_TIER1/2`, `TIER_THRESHOLD`, `ECONOMY_TECH_*` | gameplay-programmer | 1.0 | — | Income is exactly 1,000/1,500/2,000/2,500 by tier count; no code path reads outpost count for income; suite green |
| **S6-02** | **Unit upkeep** — `upkeep` on `UnitTypeDef`/`StructureDef`; `net_credit_income = gross − Σ upkeep`; start-of-turn charge; bank floors at 0; deficit locks produce/build/research; **disband** action | gameplay-programmer | 1.5 | S6-01 | `unit-upkeep.md` AC-1..AC-17 pass. ★ Derived upkeep uses `UPKEEP_GRANULARITY` and yields **100/200/200/300** for Scout/Trooper/Sniper/Heavy |
| **S6-03** | **Structure rework** — Economy Outpost **deleted**; Production Outpost → **Barracks** (+2 infantry cap); new **Factory**; per-faction structure maximums enforced at the build call site | gameplay-programmer | 1.0 | S6-01 | Build rejected past each maximum with a reason naming it; Barracks grants cap; Alliance full build-out = 10 structures / 7,300 Credits |
| **S6-04** | **Population cap** — `base_infantry_cap`, `cap_per_barracks`, `max_barracks`; produce gate; queued units count; cap falls when a Barracks dies without destroying units | gameplay-programmer | 1.0 | S6-03 | `population-cap.md` AC-1..AC-8, AC-11 pass; ceiling is exactly 10 at full build-out |
| **S6-05** | ★★ **AI re-anchor** — `CREDIT_TO_AP_RATE` 1.0 → **0.01**; `economy_value` re-pointed at research tiers; retire `completed_outpost_count`; AI must respect the cap, the deficit lock, and value a unit at **lifetime** cost (purchase + upkeep × horizon) | ai-programmer | 1.5 | S6-01..04 | Lethal-floor invariant re-verified (economy-tier score ≈1.65 < `LETHAL_FLOOR_BONUS` 3.5); Defense-Tech margin still clears `PASS_THRESHOLD`; AI never builds past a maximum or into deficit |
| **S6-06** | ⛔ **THE GATE — AI-vs-AI regression batch** | qa-lead + ai-programmer | 0.5 | S6-05 | All four pass conditions above met, recorded in `production/playtests/` as an appendix update |

### Should Have

| ID | Task | Owner | Est. | Deps | Acceptance |
|----|------|-------|-----:|------|------------|
| **S6-07** ✅ | **HUD: gross / upkeep / net** — replace the dead `base + outpost + econ_tech` breakdown (cross-review B-3); population readout; purchase preview shows its effect on net | ui-programmer | 1.0 | S6-02, S6-04 | `unit-upkeep.md` AC-19/AC-20; `population-cap.md` AC-12. ★ `net` carries the visual weight — a player must see the equilibrium coming |
| **S6-08** ✅ | **Victory/defeat presentation** — `game-hud.md` CR-9 / AC-17 / AC-22, unimplemented and carried since Sprint 5. A one-line status message is the current stopgap | ui-programmer | 1.0 | S6-06 | A real win/loss screen fires on HQ destruction and on the round cap. ★ Invisible while games never ended; player-facing the moment they do |

### Nice to Have (rides the buffer)

| ID | Task | Owner | Est. | Notes |
|----|------|-------|-----:|-------|
| **S6-09** | `/propagate-design-change` sweep — cross-review W-1/W-4/W-5: dependency reciprocity (0/11), pre-rescale arithmetic, "Production Outpost" naming across ~10 docs | producer | 0.5 | Mechanical; no conclusions change |
| **S6-10** | Factory art — re-point the retired Economy Outpost's 7 files to `struct_factory_*` + manifest | art-director | 0.5 | User-approved reuse; zero new generations |

## ★ Carried and explicitly NOT in this sprint

| Item | Why not now |
|---|---|
| **S5-03 iso-legibility playtest** ★ | Still owed, 4 sprints. **Blocked on the user, not on us.** ★ It is also the input to cross-review **B-4** (the Pillar-3 legibility budget), which should be answered before any wave-2 renderer work |
| **S5-04 swing-back playtest** ★ | Deliberately deferred **until after S6-06 passes.** Playing it now would judge a build whose central failure is known and scheduled — the same mistake that rolled it over three times |
| **S5-07 windowed sign-offs** ★ | Captures exist; human sign-off owed |
| **Any faction content** | ★ Under **CR-11** a faction needs piloted vehicles and the cap, so no faction can ship before unit classes and pilots exist (wave 2). An infantry-only faction is a fragment, not a test |
| **Unit classes, abilities, damage types, transport, promotion** | Wave 2–4. All designed, none needed to prove the economy |

## ⚠ Recorded during the sprint — for the retrospective

**S6-02's estimate was for the feature, and the feature was the small part.** The upkeep
mechanic itself (module, deficit rule, disband, 31 tests) went in cleanly and close to
estimate. What overran was everything the **×100 Credit rescale** touched, and it touched
four distinct categories, each failing differently:

| # | What broke | How it surfaced |
|---|---|---|
| 1 | `CREDIT_TO_AP_RATE` — a **conversion constant** between two differently-scaled units | Not at all. Found only by re-deriving the AI formula by hand during the cross-review |
| 2 | `UPKEEP_DIVISOR` — a **rounding function** (`ceil` on small numbers) | Not at all. Found by working the arithmetic |
| 3 | **Data files** — unit `produce_cost` / structure `build_cost` were never rescaled in S6-01 | A Scout costing 2 against an income of 1,000 |
| 4 | **Test fixtures** funded with amounts that no longer buy anything | Null-dereference in an AI test, and ~20 hardcoded cost literals |

★ **The lesson, stronger than first written:** a rescale is not done when the code compiles.
It is done when **every quantity in that unit has moved** — including the ones living in
data files and in test setup — **and** every constant that *converts* or *rounds* between
units has been re-derived. Categories 1 and 2 are invisible to grep and to the compiler.

★ **Also cost ~20 minutes: a wrong entry in `.agent/notes.md`.** It said a runner pass
rebuilds the global class cache after adding a new `class_name`. It does not — and with the
cache deleted the test runner **hangs silently** (minutes at ~0% CPU, no output), which
reads exactly like a slow test run. The rebuild is `./redot --headless --editor --quit`.
Note corrected. **A wrong note is worse than no note**, and this one had survived since
2026-07-28.

## Risks

| Risk | P | Impact | Mitigation |
|---|---|---|---|
| ★ **The batch does not flip** — matches still fail to resolve | Medium | **High** | Run it after S6-02 and again after S6-04, not only at S6-06. If bounding the economy alone is insufficient, the next lever is the map or the HQ, and PIVOT-NOTE §3.2 predicts the existing siege term should surface on its own — **if it does not, the diagnosis is wrong and that is the first thing to revisit** |
| **AI re-anchor is subtler than estimated** | Medium | High | S6-05 is 1.5d and touches the most carefully-reasoned document in the corpus. Its lethal-floor and pass-threshold invariants must be recomputed, not assumed |
| **Deleting the Economy Outpost breaks tests/data** | Low | Medium | It is referenced in `.tres` data, tests, and the AI. Grep before deleting; expect test churn |
| **Scope drift toward factions** | ★ Medium | High | The corpus is fresh and tempting. **Route everything to `production/post-gate-backlog.md`.** Sprint 4 lost its whole window to exactly this |
| **Human-gated work rolls over a 4th time** | High | Medium | Accepted and planned around — none of it is on this sprint's critical path |

## Definition of Done

### S6-07 / S6-08 complete — 2026-08-24 (`3ddcad7`, `9c65447`)

**S6-07** — the income popover was still *rendering* `base + outpost + econ_tech` long
after S6-01 deleted the Economy Outpost. Its data model had been repointed; its `_draw()`
had not, so the player saw two permanently-zero terms for mechanics that no longer exist and
could not see upkeep or net at all. Now shows `gross − upkeep = net`, with net larger and the
only coloured figure (UR-8: the player must see the equilibrium *coming*). `open_preview()`
projects net after a prospective purchase (AC-20). New `PopulationWidget` for AC-12's readout,
kept separate from income on purpose — upkeep is a gradient you can watch approach, the cap is
a hard stop.

**★ A live defect surfaced while writing that up.** AC-12's other half — "the produce
affordance is visibly disabled with a stated reason" — was not just unshipped. The population
cap was enforced in the rules (`BaseProduction.validate`), respected by the AI, and displayed
by the new widget, but **the verb menu never checked it**. A player at cap saw Produce
*enabled*, chose a unit, and got a rejection with no forewarning. Fixed in `CommandFSM`.

**S6-08** — both of CR-9's clauses, which needed genuinely different presentation rather than
one path with a swapped noun. An HQ kill explains itself; a round-limit finish explains
nothing (nothing died, and the board still looks playable), so that path also shows the
deciding metric and both scores. Required recording *why* the match ended: the deciding HQ is
already erased from `entities_by_id` by the time the HUD reads terminal state, so the cause is
unrecoverable after the fact. Adds `GameState.WinReason` + `win_reason`, and
`reason`/`metric`/`metric_by_player` on `GameOverEvent`.

**★★ AC-22 had been silently live for a sprint.** It was marked *"deferred — not testable in
VS scope, activate when `MAX_ROUNDS` ships"*. `MAX_ROUNDS` shipped in **S6-03**, and ~1 game in
7 was ending on it, untested, with no presentation. Nothing connected arming the round cap to
that AC's activation condition. **Lesson, recorded in `game-hud.md`: a deferral whose trigger
is another story's side effect will not re-open itself — name the story that satisfies it.**

Suite **1085/1085** (28 new). Slice boots clean. Regression batch unchanged at 18/21, mean 25
turns — the state additions cost nothing.

**Two presentation calls are yours to overrule** (both flagged in the GDDs, both reversible):
`unit-upkeep.md` **UOQ-5** — net gets the visual weight rather than all three figures being
equal. `game-hud.md` **OQ-2** — a capped game shows the metric and both scores.

- [x] ✅ **S6-06 gate passed** (2026-08-24, batch 5) — matches resolve on play, from both seats, with non-zero HQ damage
- [ ] `CREDIT_TO_AP_RATE` ships at 0.01 and the lethal-floor invariant is re-verified
- [ ] Derived upkeep yields 100/200/200/300 on the shipped roster
- [ ] All Must Have tasks complete and passing their acceptance criteria
- [ ] Full suite green (baseline **984/984**), 0 orphans, slice boots clean
- [ ] `/smoke-check` PASS
- [ ] No unplanned work absorbed without a recorded descope trade
- [ ] `REPORT.md` updated with the post-fix measurement
