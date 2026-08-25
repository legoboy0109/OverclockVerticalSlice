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
| **S6-09** ✅ | `/propagate-design-change` sweep — cross-review W-1/W-4/W-5: dependency reciprocity (0/11), pre-rescale arithmetic, "Production Outpost" naming across ~10 docs | producer | 0.5 | Mechanical; no conclusions change |
| **S6-10** | Factory art — re-point the retired Economy Outpost's 7 files to `struct_factory_*` + manifest | art-director | 0.5 | User-approved reuse; zero new generations |

## ⚠ Delivered beyond the plan — S6-11 … S6-38, reconstructed at close-out (2026-08-25)

> **The plan above stops at S6-10. The sprint did not.** Twenty-eight further pieces of work
> shipped and were recorded *only* in the design docs, the post-gate backlog and the session
> state — never in this file or in `sprint-status.yaml`. Reconstructed here from the commit
> history so the sprint record matches the repository.
>
> ★★ **The process failure worth naming:** tracking stopped at exactly the moment the gate
> passed. The plan had a finish line, the work did not, and nothing prompted a re-plan — so a
> sprint that delivered roughly **four times its committed scope** reads, in its own tracking
> artifacts, as if it stopped two-thirds of the way through S6-10. **A sprint plan whose scope
> is overtaken mid-flight needs re-planning, not silent extension.** Carried to the retro.
>
> ⚠ **IDs S6-29…S6-38 are assigned retroactively here**, at close-out. Only S6-11…S6-28 were
> numbered while the work happened; the action-menu block that followed was never numbered at
> all. Commits are the authority, the IDs are the index.

### Phase A — closing the cross-review and the two human-gated playtests (S6-11 … S6-16)

| ID | What shipped | Commit | ★ Why it mattered |
|----|---|---|---|
| **S6-11** | **B-4 ANSWERED** — `design/legibility-budget.md`; always-on facts capped at 5 | `91b1d5c`, `9bb7378` | The Pillar-3 aggregate that six GDDs each flagged and **nothing owned**. ★★ The finding came from the *renderer*, not the docs: the board runs **7 always-on channels carrying 5 facts** — act-state is triple-encoded from identical inputs. Deliberate a11y redundancy, kept — but it means apparent crowding is not all information, and wave 2 has slack. ⛔ **The cap is reasoned, not measured** |
| **S6-12** | **S5-03 iso-legibility gate RUN** — CONDITIONAL PASS, one blocking defect | `759fca3` | Five sprints owed. Board readable; **the Sniper does not read as owned** (hue coverage 13.3% vs roster mean 50.1%, ΔE76 12.9). ★ **An archetype's accent coverage IS its legibility** — Heavy 62% and Sniper 13% share a palette and coverage is the entire difference. ⚠ Overturned an S6-11 allocation: act-state redundancy is thinner than assumed, so crew state needs new budget |
| **S6-13** | **Sniper accent fixed** 13.3% → **43.5%**, ΔE76 12.9 → **66.5** | `6c2a54e` | New pipeline stage `promote_accent.py`. ★ Two approaches were binned first and **all three hit 45.0% exactly** — the metric could not tell them apart; only looking at them could. Constrained dilation wins because it does not invent a composition. ★ Tone chosen at **shipping scale**, not master scale |
| **S6-14** | **S5-04 swing-back playtest RUN** — ✅ PASSES both requirements | `3345275` | 0 lead changes across 18 handicapped games; mirrors average **48% doubt / 6.75 lead changes**. ★★ But the cliff is **one unit wide**: +1 Trooper → **0.00** lead changes. ★ And the **first player loses all four mirrors** by real HQ margins. Required a harness fix: the mirror cell was **n=1 disguised as n=3** |
| **S6-15** | **One-unit cliff DIAGNOSED** — a deploy-tile latch, not a snowball | `499d2d3` | ⛔ **Four enemy units on a producer's four orthogonal neighbours ended that player's game permanently.** Trace: underdog locked out from turn 14 holding **6,500 Credits**, full AP, no deficit, population headroom — every gate green except *nowhere to put it*. ★★ **Invisible until now because the S6-06 fix is what created it** — before the gate passed, the AI never pushed toward an HQ, so nothing ever camped a spawn ring |
| **S6-16** | **Deploy radius 1 → 2** — latch removed (user chose option A) | `c15447e` | Losing player on-board 10.3% → **23.1%** of turns; dead banked Credits 7,500 → **3,200**. Gate unaffected. ⚠ **And it did NOT fix the cliff — I named that as the test and it did not move.** The +1 cell still shows zero lead changes. **The latch was a defect; the cliff is a design question.** Fixing the first *separated* them |

### Phase B — the playability pass: the slice was not actually playable (S6-17 … S6-21)

| ID | What shipped | Commit | ★ Why it mattered |
|----|---|---|---|
| **S6-17/18** | Visible board cursor · six board verbs as named actions with pad bindings · correct cost currency · HUD grouped into titled panels | `8ef0bec`, `4e742c4` | ★ **The cursor was invisible and the drawing code existed** — `_board` is a *child* of the root, so the root's `_draw()` painted **under** every TileMapLayer. ★ Costs were labelled **"600 AP" for a Credit price**, never updated after the ADR-0006 split. ★ The hp glyph was authored at `Vector2(0,0)` — dead centre, behind the sprite — and **the test asserting zero was asserting the bug** |
| **S6-19** | Move-range highlights routed through the real overlay path; `VerticalSliceRoot._draw()` deleted entirely | `0fd9564` | Same root cause as the cursor. ★ **`notify_action_applied` had NO CALLER** — ADR-0015 §3's specified hook: documented, implemented, tested, never wired. ★ Overlay alphas had been **authored blind at 0.85–0.9** and never once seen; the first real frame covered ⅔ of the board in near-solid tan |
| **S6-20** | Action controls became real focusable `Button`s; new `board_menu_focus` toggle | `ab0e344` | ★ **The real finding: there were no menus.** "Build" and "End Turn" were `draw_string` calls — painted text no input could activate, and `request_build()` had no caller outside tests. ★ Trap: focus neighbours must use **relative** sibling paths — `get_path()` in `configure()` runs before the node enters the tree and silently points at nothing |
| **S6-21** | Control-binding UI **deferred** to the Settings screen (user decision), recorded in two places | `027d462` | ★ The precondition was the real content: before S6-17/S6-20 the board verbs were raw `event.keycode` matches — `match` arms rather than data — so **there was nothing to rebind**. Closed the long-standing "cai-005 InputMap wiring" backlog item |

### Phase C — the three missing screens, and a spec for the one that had none (S6-22 … S6-28)

| ID | What shipped | Commit | ★ Why it mattered |
|----|---|---|---|
| **S6-22** | **Main menu**; `run/main_scene` moved off the slice onto the menu | `867ad91` | Built to the Approved spec. ⛔ Settings shipped **present-but-inert** (`SETTINGS_AVAILABLE = false`) — omitting it would deviate from an approved spec, wiring it to nothing would open a broken screen. ★ **Two layout bugs found by LOOKING at the render, not reading the code** |
| **S6-23** | **Pause overlay**, and pause that actually freezes | `f33e5b9` | ★★ **The defect it surfaced:** `SceneTree.create_timer()` defaults to `process_always = true`, and the AI's commit pacing used the default — **pausing during the opponent's turn would have left the AI playing on behind the overlay.** Restart/Quit must un-pause *before* the scene swap or the reloaded scene opens frozen with no overlay to un-freeze it |
| **S6-24** | **Settings screen** + `GameSettings` — the project's first persistence | `f49d3de` | ★★ **Found a real defect on first render: End Turn was bound to keycode `16777218` — Godot *3*'s KEY_TAB. Godot 4's is `4194306`.** The binding was not Tab; it was nothing. The InputMap accepts any int and the tests asserted the *legend text*, not the binding. ★ Only overrides stored, so players inherit future default changes; conflicts **reported, not refused** |
| **S6-25** | Cursor-jump wired + L3 pad binding | `e931af9` | ★★ The ask was a binding; **the action had no handler** — implemented and unit-tested since ADR-0014, declared in `project.godot`, called by nothing. **Third dead hook found this way in two days.** ★ Same cause each time: *a unit test proves a function works, not that anything invokes it* |
| **S6-26** | `design/ux/settings.md` written **retroactively and labelled as such** | `d5355dd` | ★ Banner + status block say so plainly — presenting it as an ordinary spec would imply a review that never happened. Every factual claim verified against the code (8 checks). ★ Writing it surfaced **4 follow-ups nobody noticed while building** |
| **S6-27** | Settings review fixed and re-run → **APPROVED** | `ce3154e` | ★★ **B-1 was a real bug:** all four `save()` call sites **discarded the returned `Error`** — an unwritable `user://` lost the player's settings silently. Now one funnel. ★ **The retroactive banner STAYS despite approval** — 3 of 4 blocking issues had never been *decided*, only never *noticed* |
| **S6-28** | **Per-binding reset** (↺ per cell + Delete on focus) | `e36eb2a` | ★ **CELL granularity, not row** — per-row would discard the *gamepad* binding of a player who mis-bound their keyboard, the same all-or-nothing bug at smaller scale. ★ The ↺ buttons are `FOCUS_NONE` on purpose: focusable would take the table **18 → 27 tab stops** to duplicate what Delete does in one press |

### Phase D — playtest fixes and the contextual action menu (S6-29 … S6-38, retro-numbered)

| ID | What shipped | Commit | ★ Why it mattered |
|----|---|---|---|
| **S6-29** | Structures stand on their tile; status plate stops covering the HUD | `c4bd74a` | ★ `STRUCTURE_GROUND_INSET_PX` applied via `Sprite2D.offset`, deliberately **not** `position` — position is the Y-sort key *and* the tile rect `pick_regions()` builds from, and both must keep meaning "the tile". ★ **Measure the NEAR half only**: a structure's widest row usually sits in the far half, which the building is *supposed* to occlude |
| **S6-30** | **The contextual action menu** — CR-1's loop, finally on screen | `65c031e`, `55bf75d` | Not a new feature: CR-1 always specified it and `CommandFSM.menu_model()` shipped in Story 001 — **only the surface was missing.** ★★ Surfaced three latent bugs: `enter_preview` mapped Produce and Build silently onto **attack**; `try_select` took `UnitState` so **no structure was ever selectable**; Build/Produce **never highlighted their legal tiles** |
| **S6-31** | Ownership decal moved outside the base plate | `61bef19` | Buildings were covering their own ownership marker |
| **S6-32** | Action-menu `/ux-review` — 6 blocking + 8 advisory, all fixed | `e6efe56`, `60cba1a` | ★ **Two findings were real defects, not doc gaps:** `GameHud.open_ap_preview()` had **no production caller** (the projected-cost echo the spec calls a RESOLVED seam had never once rendered), and **a refused commit reached nothing** — `action_applied` fires on success only. ⇒ **Grep for callers of any API a design doc calls "resolved"** |
| **S6-33…37** | The action menu's five open questions closed: OQ-5 "boxed in" vs "out of AP" · OQ-1 Wait stand-down · OQ-2 Attack price · OQ-3 Disband row | `b350b63`, `9abaa40`, `e18863a`, `44f5cd2`, `05ac8bf`, `07521d1` | ★ `_move_entry`'s INSUFFICIENT_AP branch was **dead code** — and **an existing test asserted the bug while its NAME described the intent**. ★★ Found en route: **`Structure` was a class defined under `tests/`**, called by `GameState.start_turn` every turn — fine in-editor and headless, **would have crashed on the first turn of any export excluding `tests/`** |
| **S6-38** | Merge to `main` + evidence sidecar | `69d5bfd`, `03e6ffb` | 54 commits, 347 files, +18,707/−870 landing at once |

## ★ Carried and explicitly NOT in this sprint

| Item | Why not now |
|---|---|
| ~~**S5-03 iso-legibility playtest**~~ ★ | ✅ **OVERTAKEN — RUN 2026-08-24 (S6-12), CONDITIONAL PASS.** Once B-4 was answered (S6-11) the gate turned out to be *scriptable*: `tools/CaptureLegibility.tscn` + `analyse_legibility.py` answer 5 of its 6 measurements without a human. ⛔ **Still owes the naive-observer session** (~20 min, someone who has not seen the game) — 3 questions in §6 that no script can answer, and the gate is not *formally* passed without it |
| ~~**S5-04 swing-back playtest**~~ ★ | ✅ **OVERTAKEN — RUN 2026-08-24 (S6-14), PASSES both requirements.** The deferral was correct and its condition was met the same day the gate passed. ⛔ **Still owes human Analyses A/C/D** — ★ **D is the economy pivot's core hypothesis**: the two-budget split rests on Credits *feeling* like a tempo cost, and nothing has ever tested it |

> ★★ **Both of these had rolled over four sprints as "blocked on the user", and both turned out to
> be mostly scriptable.** The blocker was never really the human — it was that nobody had asked
> which *parts* needed one. What genuinely needs a person is now a ~20-minute observer session and
> three feel questions, not two whole playtests. **Re-examine anything labelled "blocked on the
> user" for the half a script can do.**
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

### S6-09 complete — 2026-08-24 (`f959146` + 3 doc commits)

**Factory re-statted** to `base-production.md`'s roster table (1,000 / 3 / 200; it carried the
renamed Economy Outpost's 400 / 1 / 100). ★ Which surfaced the bigger problem: the Factory
*produces nothing* — ground vehicles are wave 2 — and grants no income, yet was offered in the
build roster. Correcting the stats made the trap three times more expensive. Pulled from the roster
until it can build something. The AI already skipped it unprompted; this only ever cost the human.

Also fixed the same rename's second inheritance: the AI's economy-investment throttle still counted
a Factory build as an economy action, in **both** the shipped driver and `simulate_matches.gd`'s
hand-copied duplicate — the one whose own comment demands it "match EXACTLY ... a looser rule here
would silently simulate a different AI than the one that ships". A new parity suite pins it.

**W-1** reciprocity restored across 12 GDDs. **W-5** naming triaged by context, not find-replaced —
three documents (`base-production`, `ap-economy`, `research-tech`) turned out to have the S6 rework
bolted on top with the entire superseded body left underneath in the present tense, and now carry
dividers. **W-4** handled with scale notes rather than rewritten numbers. **Plus** the entity
registry, four sprints stale and the baseline `/consistency-check` trusts.

Suite **1089/1089**. Slice boots clean. Batch unchanged: 18/21, mean 25 turns.

⚠ **Flagged for a direction call, not changed:** Barracks (data 900 vs table 600) and Defensive
Structure (600/1 vs 500/2) drift the same way the Factory did — but they are live balance values on
a gate that has only just started passing, and Barracks throughput was one of the two levers that
fixed it. Re-statting them is a balance decision.

- [x] ✅ **S6-06 gate passed** (2026-08-24, batch 5) — matches resolve on play, from both seats, with non-zero HQ damage
- [x] ✅ `CREDIT_TO_AP_RATE` ships at 0.01 and the lethal-floor invariant is re-verified — economy tier **1.60** < `LETHAL_FLOOR_BONUS` **3.5**; kill 3.00 · HQ chip 0.75 · produce 0.26 · march 0.16 > `PASS_THRESHOLD` 0.15. All inside one order of magnitude, which is the whole point of the rate (S6-05)
- [x] ✅ Derived upkeep yields 100/200/200/300 on the shipped roster — via `UPKEEP_GRANULARITY`, pinned by test (S6-02)
- [x] ✅ All Must Have tasks complete and passing their acceptance criteria — S6-01…S6-06, plus both Should-Haves and both Nice-to-Haves
- [x] ✅ Full suite green — **1233/1233, 106 suites, 0 errors / 0 failures / 0 orphans**, re-verified on `main` 2026-08-25. Slice boots clean (exit 0). Baseline at plan time was 984
- [x] ✅ `/smoke-check` PASS — 2026-08-25, `production/qa/smoke-2026-08-25.md`
- [ ] ⛔ **NOT MET — No unplanned work absorbed without a recorded descope trade.** S6-11…S6-38 were absorbed with **no re-plan and no recorded trade**, and the tracking artifacts stopped at S6-10 while the work continued. Nothing was *lost* — every item is in the design docs and the commit history, and this file now records them — but the rule the sprint set for itself was not followed. **Recorded as a miss, not back-dated into a pass.** Carried to the retro as its first action
- [x] ✅ `REPORT.md` updated with the post-fix measurement — Addendum A, 2026-08-25
